import 'package:react/react.dart' hide body, footer, header;
import 'package:react/react_client.dart';
import 'package:react_rearch/react_rearch.dart';
import 'package:react_rearch_example/lib.dart';

/// App component.
ReactDartComponentFactoryProxy2<Component2> app = registerComponent2(_App.new);

///.
class _App extends RearchComponent {
  @override
  String get debugName => '_App';

  @override
  ReactNode? build(ComponentHandle use) {
    return div(
      {
        ...Style(
          {
            'display': 'flex',
            'flexDirection': 'column',
          },
          size: SySize(
            fullHeight: true,
          ),
        ).value,
      },
      header(
        {},
      ),
      content(
        {},
      ),
      footer(
        {},
      ),
    );
  }
}
