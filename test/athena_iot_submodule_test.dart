import 'package:flutter_test/flutter_test.dart';
import 'package:orion/backend_service/athena_iot/athena_feature_manager.dart';
import 'package:orion/backend_service/athena_iot/athena_iot_submodule.dart';

class _FakeAthenaFeatureManager extends AthenaFeatureManager {
  _FakeAthenaFeatureManager();

  bool fetchCalled = false;
  bool startCalled = false;
  bool stopCalled = false;

  @override
  Future<void> fetchAndApplyFeatureFlags() async {
    fetchCalled = true;
  }

  @override
  void startPeriodicPolling({Duration interval = const Duration(minutes: 10)}) {
    startCalled = true;
  }

  @override
  void stopPeriodicPolling() {
    stopCalled = true;
  }
}

void main() {
  test('AthenaIotSubmodule initialize/dispose delegates to manager', () async {
    final fakeManager = _FakeAthenaFeatureManager();
    final submodule = AthenaIotSubmodule(manager: fakeManager);

    await submodule.initialize();
    expect(fakeManager.fetchCalled, isTrue);
    expect(fakeManager.startCalled, isTrue);

    await submodule.dispose();
    expect(fakeManager.stopCalled, isTrue);
  });
}
