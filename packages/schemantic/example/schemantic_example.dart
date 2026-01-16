import 'package:schemantic/schemantic.dart';

part 'schemantic_example.schema.g.dart';

@Schematic()
abstract class AddressSchema {
  String get street;
  String get city;
  String get zipCode;
}

/// Define a schema using the @Schematic annotation.
/// This will generate a concrete [User] class and a [UserType] utility.
@Schematic()
abstract class UserSchema {
  String get name;
  int? get age;
  bool get isAdmin;

  // Nested schema
  AddressSchema? get address;
}

void main() async {
  // 1. Create an instance using the generated class
  final address = Address.from(
    street: '123 Main St',
    city: 'Springfield',
    zipCode: '62704',
  );

  final user = User.from(
    name: 'Alice',
    age: 30,
    isAdmin: true,
    address: address,
  );

  print('--- Instance ---');
  print('Name: ${user.name}');
  print('Age: ${user.age}');
  print('Is Admin: ${user.isAdmin}');
  print('Address: ${user.address?.street}, ${user.address?.city}');

  // 2. Serialize to JSON
  final json = user.toJson();
  print('\n--- JSON Serialization ---');
  print(json);
  // Output: {name: Alice, age: 30, isAdmin: true, address: {street: 123 Main St, city: Springfield, zipCode: 62704}}

  // 3. Parse from JSON
  final parsed = UserType.parse({
    'name': 'Bob',
    'isAdmin': false,
    'address': {
      'street': '456 Elm St',
      'city': 'Shelbyville',
      'zipCode': '62705',
    },
  });
  print('\n--- JSON Parsing ---');
  print('Parsed Name: ${parsed.name}'); // Bob
  print('Parsed City: ${parsed.address?.city}'); // Shelbyville

  // 4. Access JSON Schema at runtime
  final schema = UserType.jsonSchema();
  print('\n--- JSON Schema ---');
  print(schema.toJson());

  // 5. Validation
  print('\n--- Validation ---');

  // Valid data
  // Valid data
  final validData = <String, dynamic>{
    'name': 'Charlie',
    'isAdmin': true,
    'address': <String, dynamic>{
      'street': '789 Oak St',
      'city': 'Capital City',
      'zipCode': '62706',
    },
  };
  final validResult = await schema.validate(validData);
  if (validResult.isEmpty) {
    print('✅ Data is valid.');
  } else {
    print('❌ Validation failed: $validResult');
  }

  // Invalid data (missing required field 'isAdmin' and invalid nested field)
  final invalidData = <String, dynamic>{
    'name': 'Dave',
    'address': <String, dynamic>{
      // Missing required street, city, zipCode
    },
  };
  final invalidResult = await schema.validate(invalidData);
  if (invalidResult.isNotEmpty) {
    print('✅ Correctly detected invalid data:');
    for (final error in invalidResult) {
      print('  - $error');
    }
  }
}
