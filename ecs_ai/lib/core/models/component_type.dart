/// categories for grouping components in the sidebar
enum ComponentCategory { passive, active, source }

/// supported electronic component types with metadata
enum ComponentType {
  resistor(
    label: 'Resistor',
    category: ComponentCategory.passive,
    pinCount: 2,
    defaultValue: '1k',
    symbol: 'R',
  ),
  capacitor(
    label: 'Capacitor',
    category: ComponentCategory.passive,
    pinCount: 2,
    defaultValue: '100n',
    symbol: 'C',
  ),
  inductor(
    label: 'Inductor',
    category: ComponentCategory.passive,
    pinCount: 2,
    defaultValue: '10m',
    symbol: 'L',
  ),
  diode(
    label: 'Diode',
    category: ComponentCategory.active,
    pinCount: 2,
    defaultValue: '1N4148',
    symbol: 'D',
  ),
  led(
    label: 'LED',
    category: ComponentCategory.active,
    pinCount: 2,
    defaultValue: 'Red',
    symbol: 'LED',
  ),
  transistorNpn(
    label: 'NPN Transistor',
    category: ComponentCategory.active,
    pinCount: 3,
    defaultValue: '2N2222',
    symbol: 'Q',
  ),
  transistorPnp(
    label: 'PNP Transistor',
    category: ComponentCategory.active,
    pinCount: 3,
    defaultValue: '2N2907',
    symbol: 'Q',
  ),
  voltageSource(
    label: 'Voltage Source',
    category: ComponentCategory.source,
    pinCount: 2,
    defaultValue: '5V',
    symbol: 'V',
  ),
  currentSource(
    label: 'Current Source',
    category: ComponentCategory.source,
    pinCount: 2,
    defaultValue: '1A',
    symbol: 'I',
  ),
  ground(
    label: 'Ground',
    category: ComponentCategory.source,
    pinCount: 1,
    defaultValue: '',
    symbol: 'GND',
  ),
  junction(
    label: 'Junction',
    category: ComponentCategory.passive,
    pinCount: 1,
    defaultValue: '',
    symbol: 'J',
  );

  const ComponentType({
    required this.label,
    required this.category,
    required this.pinCount,
    required this.defaultValue,
    required this.symbol,
  });

  /// display name shown in ui
  final String label;

  /// sidebar grouping
  final ComponentCategory category;

  /// number of connection pins
  final int pinCount;

  /// default component value (e.g. '1k', '5V')
  final String defaultValue;

  /// spice-style designator prefix
  final String symbol;

  /// returns the path to the svg icon asset
  String get iconPath {
    switch (this) {
      case ComponentType.resistor:
        return 'assets/icons/resistor.svg';
      case ComponentType.capacitor:
        return 'assets/icons/capacitor.svg';
      case ComponentType.inductor:
        return 'assets/icons/inductor.svg';
      case ComponentType.diode:
        return 'assets/icons/diode.svg';
      case ComponentType.led:
        return 'assets/icons/led.svg';
      case ComponentType.transistorNpn:
        return 'assets/icons/npn.svg';
      case ComponentType.transistorPnp:
        return 'assets/icons/pnp.svg';
      case ComponentType.voltageSource:
        return 'assets/icons/voltage.svg';
      case ComponentType.currentSource:
        return 'assets/icons/current.svg';
      case ComponentType.ground:
        return 'assets/icons/ground.svg';
      case ComponentType.junction:
        return 'assets/icons/junction.svg';
    }
  }
}
