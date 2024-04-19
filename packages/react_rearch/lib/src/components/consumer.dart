part of '../components.dart';

abstract class RearchComponent extends Component2 {
  bool _needsBuild = false;

  @override
  final Context<CapsuleContainer> contextType = capsuleContainerContext;

  CapsuleContainer get _capsuleContainer => context as CapsuleContainer;

  final _willUnmountListeners = <SideEffectApiCallback>{};

  final _sideEffectData = <Object?>[];

  /// Represents a [Set] of functions that remove a dependency on a [Capsule].
  final _dependencyDisposers = <void Function()>{};

  /// Clears out the [Capsule] dependencies of this [RearchComponent].
  void _clearDependencies() {
    for (final dispose in _dependencyDisposers) {
      dispose();
    }
    _dependencyDisposers.clear();
  }

  @override
  void componentDidUpdate(
    Map<dynamic, dynamic> prevProps,
    Map<dynamic, dynamic> prevState, [
    dynamic snapshot,
  ]) {
    _clearNeedsBuild();

    super.componentDidUpdate(prevProps, prevState, snapshot);
  }

  @override
  void componentWillUnmount() {
    for (final listener in _willUnmountListeners) {
      listener();
    }

    _clearDependencies();

    // Clean up after any side effects to avoid possible leaks
    _willUnmountListeners.clear();

    super.componentWillUnmount();
  }

  @override
  ReactNode render() {
    // Clears the old dependencies (which will be repopulated via WidgetHandle)
    _clearDependencies();

    return build(
      _ComponentHandleImpl(
        _ComponentSideEffectApiProxyImpl(this),
        _capsuleContainer,
      ),
    );
  }

  ReactNode build(ComponentHandle use);

  void _markNeedsBuild() {
    if (_needsBuild) return;

    Future.microtask(forceUpdate);

    _needsBuild = true;
  }

  void _clearNeedsBuild() {
    if (!_needsBuild) return;

    _needsBuild = false;
  }
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

    component._markNeedsBuild();
  }

  @override
  void registerDispose(SideEffectApiCallback callback) =>
      component._willUnmountListeners.add(callback);

  @override
  void unregisterDispose(SideEffectApiCallback callback) =>
      component._willUnmountListeners.remove(callback);

  /// [rebuild] just marks the corresponding widget as dirty,
  /// so all affected widgets will be built together on the next frame for free.
  /// Thus, all we need to do is update all the capsules in a single txn
  /// before the widgets are built again.
  /// This works out somewhat nicely, as we can easily intermingle
  /// widget and capsule side effects within a single transaction.
  @override
  void runTransaction(void Function() sideEffectTransaction) =>
      component._capsuleContainer.runTransaction(sideEffectTransaction);
}

class _ComponentHandleImpl implements ComponentHandle {
  _ComponentHandleImpl(this.api, this.container);

  final _ComponentSideEffectApiProxyImpl api;
  final CapsuleContainer container;
  int sideEffectDataIndex = 0;

  @override
  T call<T>(Capsule<T> capsule) {
    final dispose = container.onNextUpdate(capsule, api.rebuild);
    api.component._dependencyDisposers.add(dispose);
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

    if (sideEffectDataIndex == api.component._sideEffectData.length) {
      api.component._sideEffectData.add(sideEffect(api));
    }
    return api.component._sideEffectData[sideEffectDataIndex++] as T;
  }
}