import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';

abstract class CustomerRepository {
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 200,
    String? query,
    bool forceRefresh = false,
  });

  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false});

  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false});

  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
  });

  Future<CustomerEntity> createCustomer(Map<String, dynamic> data);

  Future<CustomerEntity> getCustomerDetail(int id);

  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false});

  Future<Map<String, dynamic>> uploadCustomerPhoto(String filePath);

  Future<bool> deleteCustomer(int id);

  Future<bool> deletePendingCustomer(String clientUuid);
}
