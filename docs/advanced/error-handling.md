It is common in GraphQL to support error reporting by adding an `errors` block to a response.
Responses can contain both data and errors, for example when some fields where resolved successfully, but other fields had errors.
A field with an error is set to null, and an error is added to the `errors` block.

An error typically contains the following fields:


| field                    | type             | description |
| ------------------------ | ---------------- | --------------- |
| `message` (non-nullable) | `String!`        | a string description of the error intended for the developer as a guide to understand and correct the error |
| `locations`              | `[Location]`     | an array of code locations, where each location is a map with the keys `line` and `column`, both natural numbers starting from 1 that describe the beginning of an associated syntax element |
| `path`                   | `[String | Int]` | if the error is associated with one or more particular fields in the response, this field of the error details the paths of those response fields that experienced the error (this allows clients to identify whether a `null` result is intentional or caused by a runtime error) |
| `extensions`             | `[TypedError]`   | [see “The TypedError Interface” below](#the-typederror-interface) |

At Netflix we have a specification available for GraphQL errors.
This specification lists types of errors, and specifies how these errors map to certain GraphQL errors.
The specification can be found [here](./graphql-error-spec.md).

The DGS framework has an exception handler out-of-the-box that works according to the specification.
This exception handler handles exceptions from data fetchers.
Any `RuntimeException` is translated to a `GraphQLError` of type `INTERNAL`.
For some specific exception types, a more specific GraphQL error type is used.

| **Exception type** | **GraphQL error type** | **description** |
| ------------------------ | ---------------- | --------------- |
| `AccessDeniedException` | `PERMISSION_DENIED` | When a `@Secured` check fails |
| `DgsEntityNotFoundException` | `NOT_FOUND` | Thrown by the developer when a requested entity (e.g. based on query parameters) isn't found |

Mapping custom exceptions
-----

It can be useful to map application specific exceptions to meaningful exceptions back to the client.
You can do this by registering a `DataFetcherExceptionHandler`.
Make sure to either extend or delegate to the `DefaultDataFetcherExceptionHandler` class, this is the default exception handler of the framework.
If you don't extend/delegate to this class, you lose the framework's built-in exception handler.

The following is an example of a custom exception handler implementation.

```java
@Component
public class CustomDataFetchingExceptionHandler implements DataFetcherExceptionHandler {
    private final DefaultDataFetcherExceptionHandler defaultHandler = new DefaultDataFetcherExceptionHandler();

    @Override
    public DataFetcherExceptionHandlerResult onException(DataFetcherExceptionHandlerParameters handlerParameters) {
        if(handlerParameters.getException() instanceof MyException) {
            Map<String, Object> debugInfo = new HashMap<>();
            debugInfo.put("somefield", "somevalue");

            GraphQLError graphqlError = TypedGraphQLError.INTERNAL.message("This custom thing went wrong!")
                    .debugInfo(debugInfo)
                    .path(handlerParameters.getPath()).build();
            return DataFetcherExceptionHandlerResult.newResult()
                    .error(graphqlError)
                    .build();
        } else {
            return defaultHandler.onException(handlerParameters);
        }
    }
}
```

The following data fetcher throws `MyException`.

```java
@DgsComponent
public class HelloDataFetcher {
    @DgsData(parentType = "Query", field = "hello")
    @DgsEnableDataFetcherInstrumentation(false)
    public String hello(DataFetchingEnvironment dfe) {

        throw new MyException();
    }
}
```

Querying the `hello` field results in the following response.

```json
{
  "errors": [
    {
      "message": "This custom thing went wrong!",
      "locations": [],
      "path": [
        "hello"
      ],
      "extensions": {
        "errorType": "INTERNAL",
        "debugInfo": {
          "somefield": "somevalue"
        }
      }
    }
  ],
  "data": {
    "hello": null
  }
}
```

!!!info
    Implementing your own `DataFetcherExceptionHandler` is also useful to add custom logging.