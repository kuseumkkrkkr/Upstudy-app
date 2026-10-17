enum AiFlowGraphItemType { function, line, scatter, parametric }

class AiFlowGraphDocument {
  const AiFlowGraphDocument({
    required this.items,
    required this.settings,
    this.extensionData = const {},
  });

  final List<AiFlowGraphItem> items;
  final AiFlowGraphSettings settings;
  final Map<String, dynamic> extensionData;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...extensionData,
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
    this.parameterRange,
    this.rawTypeName,
    this.extensionData = const {},
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

  /// Canonical manuscript domain: {id, min, max, step}. Kept verbatim.
  final Map<String, dynamic>? parameterRange;

  /// Unknown wire types remain data and must not become executable functions.
  final String? rawTypeName;
  final Map<String, dynamic> extensionData;

  bool get isFunction =>
      rawTypeName == null && type == AiFlowGraphItemType.function;
  bool get isDataSeries =>
      type == AiFlowGraphItemType.line || type == AiFlowGraphItemType.scatter;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...extensionData,
      'id': id,
      'type': rawTypeName ?? type.name,
      'label': label,
      'colorHex': colorHex,
      'enabled': enabled,
      'expression': expression,
      'xValues': xValues,
      'yValues': yValues,
      if (xExpression != null) 'xExpression': xExpression,
      if (yExpression != null) 'yExpression': yExpression,
      if (tMin != null) 'tMin': tMin,
      if (tMax != null) 'tMax': tMax,
      if (traceParameterId != null) 'traceParameterId': traceParameterId,
      if (parameterRange != null) 'parameterRange': parameterRange,
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
    Map<String, dynamic>? parameterRange,
    String? rawTypeName,
    Map<String, dynamic>? extensionData,
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
      parameterRange: parameterRange ?? this.parameterRange,
      rawTypeName: rawTypeName ?? (type == null ? this.rawTypeName : null),
      extensionData: extensionData ?? this.extensionData,
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
    this.extensionData = const {},
  }) : _parameters = parameters;

  final bool showAxes;
  final bool showGrid;
  final bool lockViewport;
  final bool degreeMode;
  final AiFlowGraphViewport? viewport;
  final List<AiFlowGraphParameter>? _parameters;
  final Map<String, dynamic> extensionData;

  List<AiFlowGraphParameter> get parameters =>
      _parameters ?? const <AiFlowGraphParameter>[];

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...extensionData,
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
    Map<String, dynamic>? extensionData,
  }) {
    return AiFlowGraphSettings(
      showAxes: showAxes ?? this.showAxes,
      showGrid: showGrid ?? this.showGrid,
      lockViewport: lockViewport ?? this.lockViewport,
      degreeMode: degreeMode ?? this.degreeMode,
      viewport: viewport ?? this.viewport,
      parameters: parameters ?? this.parameters,
      extensionData: extensionData ?? this.extensionData,
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
    this.extensionData = const {},
  });

  final String id;
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;

  /// `observationX` locates a point on each curve; never a formula coefficient.
  final String role;
  final Map<String, dynamic> extensionData;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...extensionData,
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
    Map<String, dynamic>? extensionData,
  }) {
    return AiFlowGraphParameter(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
      role: role ?? this.role,
      extensionData: extensionData ?? this.extensionData,
    );
  }
}

class AiFlowGraphViewport {
  const AiFlowGraphViewport({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    this.extensionData = const {},
  });

  final double left;
  final double right;
  final double top;
  final double bottom;
  final Map<String, dynamic> extensionData;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...extensionData,
      'left': left,
      'right': right,
      'top': top,
      'bottom': bottom,
    };
  }
}
