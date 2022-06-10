Before operations (queries, mutations, and subscriptions) can be executed, their request string needs to be *parsed*
and *validated*. Performing these two steps can be expensive.

The GraphQL Java library opens up a
special [`PreparsedDocumentProvider` interface](https://www.graphql-java.com/documentation/execution#query-caching)
which intercepts these two steps and allows library consumers to cache, or modify the resulting operation.

The DGS Framework supports injecting a `PreparsedDocumentProvider` by defining a bean of the same type.

The following example uses [Caffeine](https://github.com/ben-manes/caffeine) to cache the 2500 most recent operations
for a maximum of 1 hour.

```java

@Component // Resolved by Spring
public class CachingPreparsedDocumentProvider implements PreparsedDocumentProvider {

    private final Cache<String, PreparsedDocumentEntry> cache = Caffeine
            .newBuilder()
            .maximumSize(2500)
            .expireAfterAccess(Duration.ofHours(1))
            .build();

    @Override
    public PreparsedDocumentEntry getDocument(ExecutionInput executionInput,
                                              Function<ExecutionInput, PreparsedDocumentEntry> parseAndValidateFunction) {
        return cache.get(executionInput.getQuery(), operationString -> parseAndValidateFunction.apply(executionInput));
    }
}
```

The bean can also be injected using an annotated `@Bean` method:

```java

@Configuration
public class MyDgsConfiguration {

    @Bean
    public PreparsedDocumentEntry getDocument(ExecutionInput executionInput,
                                                     Function<ExecutionInput, PreparsedDocumentEntry> parseAndValidateFunction) {
        return new CachingPreparsedDocumentProvider();
    }
}
```

Using operation variables
-----
When using `PreparsedDocumentProvider` this way, it is important that you use operation variables in your operation.
Otherwise, your cache may fill up with operations that are used only once, or contain personal information.

This means that operations like the following:

```
query DgsPersonQuery {
     person(id: "123") {
        id
        firstName
     }
}
```

Should be written as:

```
query DgsPersonQuery($personId: String!) {
     person(id: $personId) {
        id
        firstName
     }
}
```

With the `personId` variable set to `"123"` in your specific client implementation.
