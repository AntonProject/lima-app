import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/visits/presentation/view_models/lpu_doctor_select_view_model.dart';

void main() {
  test('sets every planned doctor as the initial selection', () {
    final viewModel = LpuDoctorSelectViewModel();
    addTearDown(viewModel.dispose);

    viewModel.selectDoctor('999');
    viewModel.setManager('Manager');
    viewModel.setSelectedDoctors(const ['30500', '27617']);

    expect(viewModel.state.selectedIds, {'30500', '27617'});
    expect(viewModel.state.selectedManager, isNull);
    expect(viewModel.state.mode, LpuVisitMode.single);
    expect(viewModel.state.canContinue, isTrue);
  });
}
