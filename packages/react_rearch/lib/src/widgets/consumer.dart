part of '../widgets.dart';

abstract class RearchComponent extends Component2 {
  bool _building = false;

  String get debugName;

  bool get debug => false;

  void _debug(String msg) {
    if (!debug) return;
    // ignore: avoid_print
    print('<$debugName> -- $msg');
  }

  final willUnmountListeners = <SideEffectApiCallback>{};

  final sideEffectData = <Object?>[];

  /// Represents a [Set] of functions that remove a dependency on a [Capsule].
  final dependencyDisposers = <void Function()>{};

  /// Clears out the [Capsule] dependencies of this [RearchComponent].
  void clearDependencies() {
    for (final dispose in dependencyDisposers) {
      dispose();
    }
    dependencyDisposers.clear();
  }

  @override
  void componentDidMount() {
    _debug('componentDidMount()');
    super.componentDidMount();
  }

  @override
  void componentDidUpdate(
    Map<dynamic, dynamic> prevProps,
    Map<dynamic, dynamic> prevState, [
    dynamic snapshot,
  ]) {
    _debug('componentDidUpdate()');
    super.componentDidUpdate(prevProps, prevState, snapshot);
  }

  @override
  void componentWillUnmount() {
    _debug('componentWillUnmount()');

    for (final listener in willUnmountListeners) {
      listener();
    }

    clearDependencies();

    // Clean up after any side effects to avoid possible leaks
    willUnmountListeners.clear();

    super.componentWillUnmount();
  }

  @override
  ReactNode render() {
    _debug('render()');

    _building = true;

    // Clears the old dependencies (which will be repopulated via WidgetHandle)
    clearDependencies();

    final res = build(
      _ComponentHandleImpl(
        _ComponentSideEffectApiProxyImpl(this),
        topLevelCapsuleContainer,
      ),
    );

    _building = false;

    return res;
  }

  ReactNode build(ComponentHandle use);
}

/// This is needed so that [ComponentSideEffectApi.rebuild] doesn't conflict
/// with [Component2.forceUpdate].
class _ComponentSideEffectApiProxyImpl implements ComponentSideEffectApi {
  const _ComponentSideEffectApiProxyImpl(this.component);
  final RearchComponent component;

  @override
  void rebuild([
    void Function(void Function() cancelRebuild)? sideEffectMutation,
  ]) {
    if (sideEffectMutation != null) {
      var isCanceled = false;
      sideEffectMutation(() => isCanceled = true);
      if (isCanceled) return;
    }

    if (!component._building) {
      component
        .._debug('forceUpdate()')
        ..forceUpdate();
    }
  }

  @override
  void registerDispose(SideEffectApiCallback callback) =>
      component.willUnmountListeners.add(callback);

  @override
  void unregisterDispose(SideEffectApiCallback callback) =>
      component.willUnmountListeners.remove(callback);

  /// [rebuild] just marks the corresponding widget as dirty,
  /// so all affected widgets will be built together on the next frame for free.
  /// Thus, all we need to do is update all the capsules in a single txn
  /// before the widgets are built again.
  /// This works out somewhat nicely, as we can easily intermingle
  /// widget and capsule side effects within a single transaction.
  @override
  void runTransaction(void Function() sideEffectTransaction) =>
      topLevelCapsuleContainer.runTransaction(sideEffectTransaction);
}

class _ComponentHandleImpl implements ComponentHandle {
  _ComponentHandleImpl(this.api, this.container);

  final _ComponentSideEffectApiProxyImpl api;
  final CapsuleContainer container;
  int sideEffectDataIndex = 0;

  @override
  T call<T>(Capsule<T> capsule) {
    final dispose = container.onNextUpdate(capsule, api.rebuild);
    api.component.dependencyDisposers.add(dispose);
    return container.read(capsule);
  }

  @override
  T register<T>(ComponentSideEffect<T> sideEffect) {
    /// Not available on Dart React.
    // assert(
    //   api.manager.debugDoingBuild,
    //   "You may only register side effects during a RearchConsumers's build! "
    //   'You are likely getting this error because you are calling '
    //   '"use.fooBar()" in a function callback.',
    // );

    if (sideEffectDataIndex == api.component.sideEffectData.length) {
      api.component.sideEffectData.add(sideEffect(api));
    }
    return api.component.sideEffectData[sideEffectDataIndex++] as T;
  }
}
