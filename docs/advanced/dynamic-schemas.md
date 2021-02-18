We strongly recommend primarily using schema-first development.
Most DGSs have a schema file and use the declarative, annotation-based programming model to create data fetchers and such.
That said, there are scenarios where generating the schema from another source, possibly dynamically, is required.

## Creating a schema from code

Create a schema from code by using the `@DgsTypeDefinitionFactory` annotation.
Use the `@DgsTypeDefinitionFactory` on methods inside a `@DgsComponent` class to provide a `TypeDefinitionFactory`.

The `TypeDefinitionFactory` is part of the [graphql-java](https://www.graphql-java.com) API.
You use a `TypeDefinitionFactory` to programmatically define a schema.

*Note that you can mix static schema files with one or more `DgsTypeDefinitionFactory` methods.*
The result is a schema with all the registered types merged.
This way, you can primarily use a schema-first workflow while falling back to `@DgsTypeDefinitionFactory` to add some dynamic parts to the schema.

The following is an example of a `DgsTypeDefinitionFactory`.

```java
@DgsComponent
public class DynamicTypeDefinitions {
    @DgsTypeDefinitionRegistry
    public TypeDefinitionRegistry registry() {
        TypeDefinitionRegistry typeDefinitionRegistry = new TypeDefinitionRegistry();

        ObjectTypeExtensionDefinition query = ObjectTypeExtensionDefinition.newObjectTypeExtensionDefinition().name("Query").fieldDefinition(
                FieldDefinition.newFieldDefinition().name("randomNumber").type(new TypeName("Int")).build()
        ).build();

        typeDefinitionRegistry.add(query);

        return typeDefinitionRegistry;
    }
}
```

This `TypeDefinitionRegistry` creates a field `randomNumber` on the `Query` object type.

## Creating datafetchers programmatically

If you're creating schema elements dynamically, it's likely you also need to create datafetchers dynamically. You can use the `@DgsCodeRegistry
` annotation to add datafetchers programmatically.
A method annotated `@DgsCodeRegistry` takes two arguments:

GraphQLCodeRegistry.Builder codeRegistryBuilder
TypeDefinitionRegistry registry

The method must return the modified GraphQLCodeRegistry.Builder.

The following is an example of a programmatically created datafetcher for the field created in the previous example.

```java
@DgsComponent
public class DynamicDataFetcher {
@DgsCodeRegistry
public GraphQLCodeRegistry.Builder registry(GraphQLCodeRegistry.Builder codeRegistryBuilder, TypeDefinitionRegistry registry) {
DataFetcher<Integer> df = (dfe) -> new Random().nextInt();
FieldCoordinates coordinates = FieldCoordinates.coordinates("Query", "randomNumber");

        return codeRegistryBuilder.dataFetcher(coordinates, df);
    }
}
```

## Changing schemas at runtime

It's helpful to combine creating schemas/datafetchers at runtime with dynamically re-loading the schema in some very rare use-cases.  
You can achieve this by implementing your own `ReloadSchemaIndicator`. 
You can use an external signal (e.g., reading from a message queue) to have the framework recreate the schema by executing the `@DgsTypeDefinitionFactory` and `@DgsCodeRegistry` again. 
If these methods create the schema based on external input, you have a system that can dynamically rewire its API.

For obvious reasons, this isn't an approach that you should use for typical APIs; stable APIs are generally the thing to aim for!