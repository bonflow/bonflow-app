import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/master_data.dart';
import '../data/master_data_repository.dart';

/// Master data for the UI. Shows the stored copy immediately and updates it from the server in
/// the background; [error] is set while the server is unreachable ("offline").
class MasterDataState {
  const MasterDataState({this.data, this.loading = true, this.error});

  final MasterData? data;
  final bool loading;
  final ApiError? error;
}

class MasterDataController extends Notifier<MasterDataState> {
  @override
  MasterDataState build() {
    Future.microtask(refresh);
    return const MasterDataState();
  }

  Future<void> refresh() async {
    final repository = ref.read(masterDataRepositoryProvider);
    state = MasterDataState(data: state.data, loading: true);
    if (state.data == null) {
      final cached = await repository.cached();
      if (!ref.mounted) {
        return;
      }
      state = MasterDataState(data: cached, loading: true);
    }
    try {
      final fresh = await repository.refresh();
      if (!ref.mounted) {
        return;
      }
      state = MasterDataState(data: fresh, loading: false);
    } on ApiError catch (e) {
      if (!ref.mounted) {
        return;
      }
      state = MasterDataState(data: state.data, loading: false, error: e);
    }
  }
}

final masterDataControllerProvider =
    NotifierProvider<MasterDataController, MasterDataState>(
      MasterDataController.new,
    );
