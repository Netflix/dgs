GraphQL [directives](https://www.apollographql.com/docs/apollo-server/schema/directives/) provide a way to decorate parts of a GraphQL schema with additional metadata or behavior. Custom directives enable the powerful extension of GraphQL's base functionalities through your own reusable logic.

## Use Cases

Custom directives may be useful for a variety of tasks, including but not limited to:

- Validation
- Authorization
- Data Transformation or Augmentation
- Caching or Optimizations
- Monitoring or Logging
- Adding Field Metadata

## Implementing a Custom Directive

Consider a scenario where you want to modify the formatting of a returned `String` field so that the value is transformed to uppercase. You have a couple options: either you can write a utility class within your application code and manually invoke it wherever necessary, ***or*** you can create a custom `@uppercase` GraphQL directive and apply the transformation in a declarative way across your schema where needed:

```graphql
directive @uppercase on FIELD_DEFINITION

type Query {
  greeting: String @uppercase
}
```

Here is the backing code needed to support this `@uppercase` directive:


```java
package com.example.demo.directives;

import com.netflix.graphql.dgs.DgsDirective;
import graphql.schema.DataFetcher;
import graphql.schema.DataFetcherFactories;
import graphql.schema.GraphQLFieldDefinition;
import graphql.schema.GraphQLFieldsContainer;
import graphql.schema.idl.SchemaDirectiveWiring;
import graphql.schema.idl.SchemaDirectiveWiringEnvironment;

@DgsDirective(name = "uppercase")
public class UppercaseDirective implements SchemaDirectiveWiring {

    @Override
    public GraphQLFieldDefinition onField(SchemaDirectiveWiringEnvironment<GraphQLFieldDefinition> env) {
        GraphQLFieldsContainer fieldsContainer = env.getFieldsContainer();
        GraphQLFieldDefinition fieldDefinition = env.getFieldDefinition();

        DataFetcher<?> originalDataFetcher = env.getCodeRegistry().getDataFetcher(fieldsContainer, fieldDefinition);
        DataFetcher<?> dataFetcher = DataFetcherFactories.wrapDataFetcher(
                originalDataFetcher,
                (dataFetchingEnvironment, value) -> {
                    if (value instanceof String) {
                        return ((String) value).toUpperCase();
                    }
                    return value;
                }
        );

        env.getCodeRegistry().dataFetcher(fieldsContainer, fieldDefinition, dataFetcher);

        return fieldDefinition;
    }
}
```

In this example, the `UppercaseDirective` class implements `SchemaDirectiveWiring` and overrides its `onField` method, where the logic for transforming the value to uppercase lives. The original `DataFetcher` for the field is wrapped in a new one, which applies the uppercase logic before returning the value. The `@DgsDirective` annotation ensures that the custom directive is registered with the Spring framework.

Custom directives can be implemented for various components of your GraphQL schema, not just field definitions. To learn more, explore the [graphql-java SDL directives documentation](https://www.graphql-java.com/documentation/sdl-directives).
