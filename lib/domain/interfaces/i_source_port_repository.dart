import '../entities/source_port.dart';

abstract class ISourcePortRepository {
  Future<List<SourcePort>> getPorts();
  Future<void> savePort(SourcePort port);
  Future<void> deletePort(String id);
}
