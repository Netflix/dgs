Use a schema-first approach for [GraphQL] in most cases.
Most [DGS]s have a schema file and use the declarative, annotation based, programming model to create data fetchers and such.

## Creating a Schema from Code during Startup

There are scenarios however in which it is better to create a schema from code, during startup of the application.
An example is a GraphQL schema which is derived from another schema, or in code generation scenarios.

The DGS framework supports this by letting users register a `TypeDefinitionRegistry` and `GraphQLCodeRegistry`, both concepts from the `graphql-java` library.
The `TypeDefinitionRegistry` represents a schema and `GraphQLCodeRegistry` the mapping from fields to data fetchers.
Both are concepts from the `graphql-java` core library.

The types defined in a provided `TypeDefinitionRegistry` are merged<!-- http://go/pv --> with any schema files when available<!-- when what is available? the types or the schema? -->.
A combination of data fetchers registered using annotations and a `GraphQLCodeRegistry` works<!-- a more precise verb would be better here --> as well.

The following is an example of creating a `TypeDefinitionRegistry`.

```java
@Configuration
public class ExtraTypeDefinitionRegistry {
    @Bean
    public TypeDefinitionRegistry registry() {
        ObjectTypeExtensionDefinition objectTypeExtensionDefinition = ObjectTypeExtensionDefinition.newObjectTypeExtensionDefinition().name("Query").fieldDefinition(FieldDefinition.newFieldDefinition().name("myField").type(new TypeName("String")).build())
                .build();

        TypeDefinitionRegistry typeDefinitionRegistry = new TypeDefinitionRegistry();
        typeDefinitionRegistry.add(objectTypeExtensionDefinition);
        
        return typeDefinitionRegistry;
    }
}
```

This `TypeDefinitionRegistry` creates a field `myField` on the `Query` object type.
This means there also needs to be<!-- http://go/pv --> a datafetcher for this field, which is created<!-- http://go/pv --> using<!-- http://go/pv --> the `@DgsCodeRegistry` annotation.

```java
@DgsComponent
public class ExtraCodeRegistry {

    @Autowired
    DgsDataFetcherFactory dgsDataFetcherFactory;

    @DgsCodeRegistry
    public GraphQLCodeRegistry.Builder registry(GraphQLCodeRegistry.Builder codeRegistryBuilder, TypeDefinitionRegistry registry) {
        DataFetcher<String> df = (dfe) -> "yes, my extra field!";
        FieldCoordinates coordinates = FieldCoordinates.coordinates("Query", "myField");
        DataFetcher<Object> dgsDataFetcher = dgsDataFetcherFactory.createDataFetcher(coordinates, df);

        return codeRegistryBuilder.dataFetcher(coordinates, dgsDataFetcher);
    }
}
```

Note how this example calls a method of the `DgsDataFetcherFactory` to create the data fetcher. 
By using this factory, the data fetcher gets all the extra features that DGS data fetchers have, such as tracing.

## Generating a Schema from Java or Kotlin Classes

An alternative way to start from code is to convert the classes from your existing Java or Kotlin code into GraphQL schemas with the [GraphQL Schema Generator](https://docs.google.com/presentation/d/1nGf5-gbzet63_z0sGBvhVQAtO_F4A2ZgSsUnfjFmYnE).
This tool is good enough to generate an initial schema that conforms to your classes, but you will then need to manually go through the generated schema and improve or correct it.
REST or [gRPC] entities do not always map well to GraphQL types:

* [graphql-code-to-schema Installation and Use Instructions](https://stash.corp.netflix.com/projects/CMENG/repos/graphql-code-to-schema/browse/README.md)

--8<-- "docs/reference_links"

