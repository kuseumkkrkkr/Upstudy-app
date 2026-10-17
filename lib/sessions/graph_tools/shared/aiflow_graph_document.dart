enum AiFlowGraphItemType { function, line, scatter, parametric }

class AiFlowGraphDocument {
  const AiFlowGraphDocument({required this.items, required this.settings});

  final List<AiFlowGraphItem> items;
  final AiFlowGraphSettings settings;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((item) => item.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }
}

class AiFlowGraphItem {
  const AiFlowGraphItem({
    required this.id,
    required this.type,
    required this.label,
    required this.colorHex,
    this.enabled = true,
    this.expression,
    this.xValues,
    this.yValues,
    this.xExpression,
    this.yExpression,
    this.tMin,
    this.tMax,
    this.traceParameterId,
  });

  final String id;
  final AiFlowGraphItemType type;
  final String label;
  final String colorHex;
  final bool enabled;
  final String? expression;
  final List<double>? xValues;
  final List<double>? yValues;

  /// Arithmetic x(t), y(t), bounded domain, and optional settings slider ID.
  final String? xExpression;
  final String? yExpression;
  final double? tMin;
  final double? tMax;
  final String? traceParameterId;

  bool get isFunction => type == AiFlowGraphItemType.function;
  bool get isDataSeries =>
      type == AiFlowGraphItemType.line || type == AiFlowGraphItemType.scatter;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'label': label,
      'colorHex': colorHex,
      'enabled': enabled,
      'expression': expression,
      'xValues': xValues,
      'yValues': yValues,
      if (type == AiFlowGraphItemType.parametric) ...{
        'xExpression': xExpression,
        'yExpression': yExpression,
        'tMin': tMin,
        'tMax': tMax,
        if (traceParameterId != null) 'traceParameterId': traceParameterId,
      },
    };
  }

  AiFlowGraphItem copyWith({
    String? id,
    AiFlowGraphItemType? type,
    String? label,
    String? colorHex,
    bool? enabled,
    String? expression,
    List<double>? xValues,
    List<double>? yValues,
    String? xExpression,
    String? yExpression,
    double? tMin,
    double? tMax,
    String? traceParameterId,
  }) {
    return AiFlowGraphItem(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      colorHex: colorHex ?? this.colorHex,
      enabled: enabled ?? this.enabled,
      expression: expression ?? this.expression,
      xValues: xValues ?? this.xValues,
      yValues: yValues ?? this.yValues,
      xExpression: xExpression ?? this.xExpression,
      yExpression: yExpression ?? this.yExpression,
      tMin: tMin ?? this.tMin,
      tMax: tMax ?? this.tMax,
      traceParameterId: traceParameterId ?? this.traceParameterId,
    );
  }
}

class AiFlowGraphSettings {
  const AiFlowGraphSettings({
    this.showAxes = true,
    this.showGrid = true,
    this.lockViewport = false,
    this.degreeMode = false,
    this.viewport,
    List<AiFlowGraphParameter>? parameters,
  }) : _parameters = parameters;

  final bool showAxes;
  final bool showGrid;
  final bool lockViewport;
  final bool degreeMode;
  final AiFlowGraphViewport? viewport;
  final List<AiFlowGraphParameter>? _parameters;

  List<AiFlowGraphParameter> get parameters =>
      _parameters ?? const <AiFlowGraphParameter>[];

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'showAxes': showAxes,
      'showGrid': showGrid,
      'lockViewport': lockViewport,
      'degreeMode': degreeMode,
      'viewport': viewport?.toJson(),
      'parameters': parameters.map((parameter) => parameter.toJson()).toList(),
    };
  }

  AiFlowGraphSettings copyWith({
    bool? showAxes,
    bool? showGrid,
    bool? lockViewport,
    bool? degreeMode,
    AiFlowGraphViewport? viewport,
    List<AiFlowGraphParameter>? parameters,
  }) {
    return AiFlowGraphSettings(
      showAxes: showAxes ?? this.showAxes,
      showGrid: showGrid ?? this.showGrid,
      lockViewport: lockViewport ?? this.lockViewport,
      degreeMode: degreeMode ?? this.degreeMode,
      viewport: viewport ?? this.viewport,
      parameters: parameters ?? this.parameters,
    );
  }
}

class AiFlowGraphParameter {
  const AiFlowGraphParameter({
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 0.1,
    this.role = 'coefficient',
  });

  final String id;
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;

  /// `observationX` locates a point on each curve; never a formula coefficient.
  final String role;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'value': value,
      'min': min,
      'max': max,
      'step': step,
      if (role != 'coefficient') 'role': role,
    };
  }

  AiFlowGraphParameter copyWith({
    String? id,
    String? label,
    double? value,
    double? min,
    double? max,
    double? step,
    String? role,
  }) {
    return AiFlowGraphParameter(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
      role: role ?? this.role,
    );
  }
}

class AiFlowGraphViewport {
  const AiFlowGraphViewport({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  final double left;
  final double right;
  final double top;
  final double bottom;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'left': left,
      'right': right,
      'top': top,
      'bottom': bottom,
    };
  }
}
