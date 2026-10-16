"""Strict, non-executable BookData import. Unknown structures fail rather than vanish."""
from __future__ import annotations

import ast
import copy
import hashlib
import json
import math
import re
from api.book_activity import validate_activity

MAX_SOURCE_BYTES = 512 * 1024
TEMPLATES = set('opening concept principle experiment example solution practice summary'.split())
BLOCKS = set('lead paragraph definition theorem formula symbols derivation visual graph question thinking solutionStep verification hint answer misconception summary checklist'.split())
FUNCTIONS = set('abs max min sqrt pow exp ln log sin cos tan ceil floor round'.split())
RESERVED = FUNCTIONS | {'x', 'pi', 'e', 'constructor', 'prototype', 'window', 'parent', 'document', 'globalThis', 'this'}


def object_fields(value, fields, path):
    if not isinstance(value, dict):
        raise ValueError(f'{path}: object required')
    unknown = set(value) - set(fields.split())
    if unknown:
        raise ValueError(f'{path}: unsupported fields: {", ".join(sorted(unknown))}')


def text(value, path, limit=4000):
    if not isinstance(value, str) or len(value) > limit:
        raise ValueError(f'{path}: text exceeds {limit} characters or is invalid')


def sequence(value, path, limit=100):
    if not isinstance(value, list) or len(value) > limit:
        raise ValueError(f'{path}: list exceeds {limit} entries or is invalid')
    return value


def strings(value, path, limit=100, length=4000):
    for entry in sequence(value, path, limit):
        text(entry, path, length)


def number(value, path):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or abs(value) > 1e9:
        raise ValueError(f'{path}: finite number within +/-1e9 required')


def validate_expression(expression, parameters=()):
    """Validate arithmetic AST, never compile/eval author expressions."""
    text(expression, 'graph.expression', 1000)
    source = re.sub(r'^\s*y\s*=\s*', '', expression, flags=re.I)
    for old, new in [('×', '*'), ('÷', '/'), ('−', '-'), ('π', 'pi'), ('PI', 'pi'), ('^', '**')]:
        source = source.replace(old, new)
    source = re.sub(r'\bE\b', 'e', source).strip()
    try:
        tree = ast.parse(source, mode='eval')
    except (SyntaxError, RecursionError) as error:
        raise ValueError('graph.expression: invalid arithmetic') from error
    nodes = list(ast.walk(tree))
    if len(nodes) > 160:
        raise ValueError('graph.expression: expression too complex')
    for node in nodes:
        if isinstance(node, ast.Name):
            if node.id not in {'x', 'pi', 'e', *FUNCTIONS, *parameters}:
                raise ValueError('graph.expression: unknown identifier')
        elif isinstance(node, ast.Call):
            if not isinstance(node.func, ast.Name) or node.func.id not in FUNCTIONS or node.keywords or not 1 <= len(node.args) <= 8:
                raise ValueError('graph.expression: unsupported function call')
        elif isinstance(node, ast.Constant):
            number(node.value, 'graph.expression')
        elif not isinstance(node, (ast.Expression, ast.BinOp, ast.UnaryOp, ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Pow, ast.UAdd, ast.USub, ast.Load)):
            raise ValueError('graph.expression: only arithmetic is supported')


def validate_graph(graph):
    object_fields(graph, 'items settings', 'graph')
    settings = graph.get('settings')
    object_fields(settings, 'showAxes showGrid lockViewport degreeMode viewport parameters', 'graph.settings')
    names = set()
    for parameter in sequence(settings.get('parameters', []), 'graph.parameters', 16):
        object_fields(parameter, 'id label value min max step', 'graph.parameter')
        name = parameter.get('id')
        if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,31}', name) or name in RESERVED or name in names:
            raise ValueError('graph.parameter: invalid or duplicate identifier')
        names.add(name)
        text(parameter.get('label', ''), 'graph.parameter.label', 120)
        for field in ('value', 'min', 'max', 'step'):
            number(parameter.get(field), 'graph.parameter.' + field)
        if not parameter['min'] <= parameter['value'] <= parameter['max'] or parameter['min'] >= parameter['max'] or not 0 < parameter['step'] <= parameter['max'] - parameter['min']:
            raise ValueError('graph.parameter: invalid range')
    for field in ('showAxes', 'showGrid', 'lockViewport', 'degreeMode'):
        if field in settings and not isinstance(settings[field], bool):
            raise ValueError('graph.settings: booleans required')
    if 'viewport' in settings:
        viewport = settings['viewport']
        object_fields(viewport, 'left right top bottom', 'graph.viewport')
        for field in ('left', 'right', 'top', 'bottom'):
            number(viewport.get(field), 'graph.viewport.' + field)
        if viewport['left'] >= viewport['right'] or viewport['bottom'] >= viewport['top']:
            raise ValueError('graph.viewport: invalid bounds')
    for item in sequence(graph.get('items'), 'graph.items', 32):
        object_fields(item, 'id type label colorHex enabled expression xValues yValues', 'graph.item')
        text(item.get('id', ''), 'graph.item.id', 120)
        text(item.get('label', ''), 'graph.item.label', 200)
        if not re.fullmatch(r'#[0-9a-fA-F]{6}', item.get('colorHex', '#1B402B')):
            raise ValueError('graph.item: invalid color')
        if 'enabled' in item and not isinstance(item['enabled'], bool):
            raise ValueError('graph.item.enabled: boolean required')
        if item.get('type') == 'function':
            validate_expression(item.get('expression'), names)
        elif item.get('type') in ('line', 'scatter'):
            xs, ys = item.get('xValues'), item.get('yValues')
            for values in (xs, ys):
                for value in sequence(values, 'graph.coordinates', 2000):
                    number(value, 'graph.coordinate')
            if len(xs) != len(ys):
                raise ValueError('graph.coordinates: matching lengths required')
        else:
            raise ValueError('graph.item: unsupported graph type')


def validate_visual(visual):
    object_fields(visual, 'kind title caption formula items rows image_source', 'visual')
    if visual.get('kind') not in {'formula', 'steps', 'table', 'signChart', 'flow', 'image', 'callout'}:
        raise ValueError('visual: unsupported kind')
    for field in ('title', 'caption', 'formula', 'image_source'):
        text(visual.get(field, ''), 'visual.' + field)
    strings(visual.get('items', []), 'visual.items')
    for row in sequence(visual.get('rows', []), 'visual.rows'):
        strings(row, 'visual.row', 20, 500)
    validate_image(visual.get('image_source', ''))


def validate_image(source):
    text(source, 'image', 2000)
    if source and not (source.startswith('https://') or source.startswith('assets/')):
        raise ValueError('image: only HTTPS or bundled assets are supported')


def validate_book(book):
    object_fields(book, 'schema_version title subtitle category tags cover_color curriculum_version standard_codes chapters', 'book')
    version = book.get('schema_version', 1)
    if type(version) is not int or version not in (1, 2):
        raise ValueError('book.schema_version: only V1 and V2 are supported')
    activity_ids = set()
    text(book.get('title'), 'book.title', 120)
    if not book['title'].strip():
        raise ValueError('book.title: required')
    for field, limit in [('subtitle', 300), ('category', 64), ('curriculum_version', 40)]:
        text(book.get(field, ''), 'book.' + field, limit)
    strings(book.get('tags', []), 'book.tags', 32, 80)
    strings(book.get('standard_codes', []), 'book.standard_codes', 32, 80)
    if 'cover_color' in book and book['cover_color'] is not None:
        value = book['cover_color']
        if type(value) is not int or not 0 <= value <= 4294967295:
            raise ValueError('book.cover_color: ARGB integer required')
    chapters = sequence(book.get('chapters'), 'book.chapters', 80)
    if not chapters:
        raise ValueError('book.chapters: required')
    for chapter in chapters:
        object_fields(chapter, 'title intro sections visuals pages', 'chapter')
        text(chapter.get('title'), 'chapter.title', 160)
        strings(chapter.get('intro', []), 'chapter.intro')
        for visual in sequence(chapter.get('visuals', []), 'chapter.visuals'):
            validate_visual(visual)
        for section in sequence(chapter.get('sections', []), 'chapter.sections'):
            object_fields(section, 'title paragraphs images graph visuals', 'section')
            text(section.get('title'), 'section.title', 160)
            strings(section.get('paragraphs', []), 'section.paragraphs')
            for image in sequence(section.get('images', []), 'section.images', 32):
                validate_image(image)
            if 'graph' in section:
                validate_graph(section['graph'])
            for visual in sequence(section.get('visuals', []), 'section.visuals'):
                validate_visual(visual)
        for page in sequence(chapter.get('pages', []), 'chapter.pages', 100):
            object_fields(page, 'id template title kicker blocks', 'page')
            for field in ('id', 'title', 'kicker'):
                text(page.get(field, ''), 'page.' + field, 160)
            if page.get('template') not in TEMPLATES:
                raise ValueError('page: unsupported template')
            for block in sequence(page.get('blocks'), 'page.blocks', 50):
                object_fields(block, 'type title text formula items rows visual graph activity', 'block')
                if block.get('type') == 'activity':
                    if version != 2:
                        raise ValueError('block.activity: requires schema_version 2')
                    validate_activity(block.get('activity'))
                    activity_id = block['activity']['id']
                    if activity_id in activity_ids:
                        raise ValueError('block.activity: duplicate id')
                    activity_ids.add(activity_id)
                    if set(block) - {'type', 'title', 'text', 'activity', 'formula', 'items', 'rows'} or any(block.get(field) for field in ('formula', 'items', 'rows')):
                        raise ValueError('block.activity: cannot mix other payloads')
                elif block.get('type') not in BLOCKS or 'activity' in block:
                    raise ValueError('block: unsupported type or activity payload')
                for field in ('title', 'text', 'formula'):
                    text(block.get(field, ''), 'block.' + field)
                strings(block.get('items', []), 'block.items')
                for row in sequence(block.get('rows', []), 'block.rows'):
                    strings(row, 'block.row', 20, 500)
                if 'graph' in block:
                    validate_graph(block['graph'])
                if 'visual' in block:
                    validate_visual(block['visual'])
    return book


def parse_import(source, expected_sha256):
    if not isinstance(source, str) or len(source.encode('utf-8')) > MAX_SOURCE_BYTES:
        raise ValueError('source: UTF-8 JSON must not exceed 512 KiB')
    digest = hashlib.sha256(source.replace('\r\n', '\n').encode('utf-8')).hexdigest()
    if not isinstance(expected_sha256, str) or digest != expected_sha256.lower():
        raise ValueError('source: SHA-256 mismatch')
    try:
        book = json.loads(source, parse_constant=_reject_constant, object_pairs_hook=_unique_object)
    except (json.JSONDecodeError, RecursionError) as error:
        raise ValueError('source: invalid JSON') from error
    return validate_book(book), digest


def migrate_v1_to_v2(book):
    """Explicit lossless copy; never invent quiz answers or mutate author source."""
    validate_book(book)
    migrated = copy.deepcopy(book)
    migrated['schema_version'] = 2
    return validate_book(migrated)


def _reject_constant(_):
    raise ValueError('source: non-finite JSON is not supported')


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('source: duplicate JSON keys are not supported')
        result[key] = value
    return result
