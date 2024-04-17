part of '0.section.dart';

ReactElement firstSection(
        // {required String foo,}
        ) =>
    _firstSection({
      // _Props.fooField: foo,
    });

extension _FirstSectionProps on _Section {
  // static const fooField = 'foo';
  // int get foo => props[fooField] as String;
}

class _FirstSection extends _Section {
  @override
  String get title => 'First Section';

  @override
  ReactNode buildContent(
    ComponentHandle use,
  ) {
    return div(
      {
        ...Style(
          {},
          size: SySize(
              // fullHeight: true,
              ),
        ).value,
      },
      'Section 1 content',
    );
  }
}

ReactDartComponentFactoryProxy2<Component2> _firstSection =
    registerComponent2(_FirstSection.new);
