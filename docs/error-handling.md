It is common in GraphQL to support error reporting by adding an `errors` block to a response.
Responses can contain both data and errors, for example when some fields where resolved successfully, but other fields had errors.
A field with an error is set to null, and an error is added to the `errors` block.

The DGS framework has an exception handler out-of-the-box that works according to the specification described in the `Error Specification` section on this page.
This exception handler handles exceptions from data fetchers.
Any `RuntimeException` is translated to a `GraphQLError` of type `INTERNAL`.
For some specific exception types, a more specific GraphQL error type is used.

| **Exception type** | **GraphQL error type** | **description** |
| ------------------------ | ---------------- | --------------- |
| `AccessDeniedException` | `PERMISSION_DENIED` | When a `@Secured` check fails |
| `DgsEntityNotFoundException` | `NOT_FOUND` | Thrown by the developer when a requested entity (e.g. based on query parameters) isn't found |


# Handling exceptions
It can be useful to map application specific exceptions to meaningful exceptions back to the client.
The framework provides two different mechanisms to achieve this.

## Mapping custom exceptions with @ControllerAdvice
The easiest way to manually map exceptions is to use `@ControllerAdvice` from Spring for GraphQL.
Annotate a class with `@ControllerAdvice`, and add a method annotated with `@GraphQlExceptionHandler` for each type of exception you want to handle.
The method must take an argument of the type of exception it should handle, and must return `GraphQLError`.
If no matching method is found, the framework falls back to the built-in error handling from the framework.

```java
@ControllerAdvice
public class ControllerExceptionHandler {
    @GraphQlExceptionHandler
    public GraphQLError handle(IllegalArgumentException ex) {
        return GraphQLError.newError().errorType(ErrorType.BAD_REQUEST).message("Handled an IllegalArgumentException!").build();
    }
}
```

## Mapping custom exceptions by implementing DataFetcherExceptionHandler

You can also register a component of type `DataFetcherExceptionHandler`, which is an interface from graphql-java.
Make sure to delegate to the `DefaultDataFetcherExceptionHandler` class, this is the default exception handler of the framework.
If you don't delegate to this class, you lose the framework's built-in exception handler.

The following is an example of a custom exception handler implementation.

```java
@Component
public class MyExceptionHandler implements DataFetcherExceptionHandler {

   @Override
   public CompletableFuture<DataFetcherExceptionHandlerResult> handleException(DataFetcherExceptionHandlerParameters handlerParameters) {
      if (handlerParameters.getException() instanceof RuntimeException) {
         Map<String, Object> debugInfo = new HashMap<>();
         debugInfo.put("somefield", "somevalue");

         GraphQLError graphqlError = TypedGraphQLError.newInternalErrorBuilder()
                 .message("This custom thing went wrong!")
                 .debugInfo(debugInfo)
                 .path(handlerParameters.getPath()).build();

         DataFetcherExceptionHandlerResult result = DataFetcherExceptionHandlerResult.newResult()
                 .error(graphqlError)
                 .build();

         return CompletableFuture.completedFuture(result);
      } else {
         return new DefaultDataFetcherExceptionHandler().handleException(handlerParameters);
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

# Error specification
There are two families of errors we typically encounter for GraphQL:

1. **Comprehensive Errors.**
   These are unexpected errors and do not represent a condition that the end user can be expected to fix.
   Errors of this sort are generally applicable to many types and fields.
   Such errors appear in the `errors` array in the GraphQL response.
1. **Errors as Data.**
   These are errors that are informative to the end user (for example: “this title is not available in your country” or “your account has been suspended”).
   Errors of this sort are typically specific to a particular use case and apply only to certain fields or to a certain subset of fields.
   These errors are part of the GraphQL schema.

## The GraphQLError Interface

The GraphQL specification provides minimal guidance on the structure of an error.
The only required field is a `message` String, which has no defined format.
In Studio Edge we would like to have a stronger, more expressive contract.
Here is the definition we are using:

| **field**                | **type**         | **description** |
| ------------------------ | ---------------- | --------------- |
| `message` (non-nullable) | `String!`        | a string description of the error intended for the developer as a guide to understand and correct the error |
| `locations`              | `[Location]`     | an array of code locations, where each location is a map with the keys `line` and `column`, both natural numbers starting from 1 that describe the beginning of an associated syntax element |
| `path`                   | `[String | Int]` | if the error is associated with one or more particular fields in the response, this field of the error details the paths of those response fields that experienced the error (this allows clients to identify whether a `null` result is intentional or caused by a runtime error) |
| `extensions`             | `TypedError`   | [see “The TypedError Interface” below](#the-typederror-interface) |


```graphql
"""
Error format as defined in GraphQL Spec
"""
interface GraphQLError {
    message: String! // Required by GraphQL Spec
    locations: [Location] // See GraphQL Spec
    path: [String | Int] // See GraphQL Spec
    extensions: TypedError
}
```


See [the GraphQL specification: Errors](http://spec.graphql.org/June2018/#sec-Errors) for more information.

### The TypedError Interface

Studio Edge defines `TypedError` as follows:

| **field**                  | **type**      | **description** |
| -------------------------- | ------------- | --------------- |
| `errorType` (non-nullable) | `ErrorType!`  | an enumerated error code that is meant as a fairly coarse characterization of an error, sufficient for client-side branching logic |
| `errorDetail`              | `ErrorDetail` | an enumeration that provides more detail about the error, including its specific cause (the elements of this enumeration are subject to change and are not documented here) |
| `origin`                   | `String`      | the name of the source that issued the error (for instance the name of a backend service, DGS, gateway, client library, or client app) |
| `debugInfo`                | `DebugInfo`   | if the request included a flag indicating that it wanted debug information, this field contains that additional information (such as a stack trace or additional reporting from an upstream service) |
| `debugUri`                 | `String`      | the URI of a page that contains additional information that may be helpful in debugging the error (this could be a generic page for errors of this sort, or a specific page about the particular error instance) |


```graphql
interface TypedError {
    """
    An error code from the ErrorType enumeration.
    An errorType is a fairly coarse characterization
    of an error that should be sufficient for client
    side branching logic.
    """
    errorType: ErrorType!

    """
    The ErrorDetail is an optional field which will
    provide more fine grained information on the error
    condition. This allows the ErrorType enumeration to
    be small and mostly static so that application branching
    logic can depend on it. The ErrorDetail provides a
    more specific cause for the error. This enumeration
    will be much larger and likely change/grow over time.
    """
    errorDetail: ErrorDetail

    """
    Indicates the source that issued the error. For example, could
    be a backend service name, a domain graph service name, or a
    gateway. In the case of client code throwing the error, this
    may be a client library name, or the client app name.
    """
    origin: String

    """
    Optionally provided based on request flag
    Could include e.g. stacktrace or info from
    upstream service
    """
    debugInfo: DebugInfo

    """
    Http URI to a page detailing additional
    information that could be used to debug
    the error. This information may be general
    to the class of error or specific to this
    particular instance of the error.
    """
    debugUri: String
}
```

### The ErrorType Enumeration

The following table shows the available `ErrorType` `enum` values:

| **type**              | **description** | **HTTP analog**   |
| --------------------- | --------------- | ----------------- |
| `BAD_REQUEST`         | This indicates a problem with the request. Retrying the same request is not likely to succeed. An example would be a query or argument that cannot be deserialized. | 400 Bad Request |
| `FAILED_PRECONDITION` | The operation was rejected because the system is not in a state required for the operation’s execution. For example, the directory to be deleted is non-empty, an `rmdir` operation is applied to a non-directory, etc. Use `UNAVAILABLE` instead if the client can retry just the failing call without waiting for the system state to be explicitly fixed. | 400 Bad Request, or 500 Internal Server Error |
| `INTERNAL`            | This indicates that an unexpected internal error was encountered: some invariants expected by the underlying system have been broken. This error code is reserved for serious errors. | 500 Internal Server Error |
| `NOT_FOUND`           | This could apply to a resource that has never existed (e.g. bad resource id), or a resource that no longer exists (e.g. cache expired). Note to server developers: if a request is denied for an entire class of users, such as gradual feature rollout or undocumented allowlist, `NOT_FOUND` may be used. If a request is denied for some users within a class of users, such as user-based access control, `PERMISSION_DENIED` must be used. | 404 Not Found |
| `PERMISSION_DENIED`   | This indicates that the requester does not have permission to execute the specified operation. `PERMISSION_DENIED` must not be used for rejections caused by exhausting some resource or quota. `PERMISSION_DENIED` must not be used if the caller cannot be identified (use `UNAUTHENTICATED` instead for those errors). This error does not imply that the request is valid or the requested entity exists or satisfies other pre-conditions. | 403 Forbidden |
| `UNAUTHENTICATED`     | This indicates that the request does not have valid authentication credentials but the route requires authentication. | 401 Unauthorized |
| `UNAVAILABLE`         | This indicates that the service is currently unavailable. This is most likely a transient condition, which can be corrected by retrying with a backoff. | 503 Unavailable |
| `UNKNOWN`             | This error may be returned, for example, when an error code received from another address space belongs to an error space that is not known in this address space. Errors raised by APIs that do not return enough error information may also be converted to this error. If a client sees an `errorType` that is not known to it, it will be interpreted as `UNKNOWN`. Unknown errors *must not* trigger any special behavior. They *may* be treated by an implementation as being equivalent to `INTERNAL`. | 520 Unknown Error |

<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">
The HTTP analogs are only rough mappings that are given here to provide a quick conceptual explanation of the semantics of the error by showing their analogs in the HTTP specification.
</div>