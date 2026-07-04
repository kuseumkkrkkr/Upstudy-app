enum AiFlowGraphItemType { function, line, scatter }

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
  });

  final String id;
  final AiFlowGraphItemType type;
  final String label;
  final String colorHex;
  final bool enabled;
  final String? expression;
  final List<double>? xValues;
  final List<double>? yValues;

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
  });

  final String id;
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'value': value,
      'min': min,
      'max': max,
      'step': step,
    };
  }

  AiFlowGraphParameter copyWith({
    String? id,
    String? label,
    double? value,
    double? min,
    double? max,
    double? step,
  }) {
    return AiFlowGraphParameter(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
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
