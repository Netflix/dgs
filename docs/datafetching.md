In the [getting started guide](index.md) we introduced the `@DgsQuery` annotation, which you use to create a data fetcher. In this section, we look at some of the finer details of datafetchers.

## The @DgsData, @DgsQuery, @DgsMutation and @DgsSubscription Annotations
You use the `@DgsData` annotation on a Java/Kotlin method to make that method a datafetcher.
The method must be in a `@DgsComponent` class.
The `@DgsData` annotation has two parameters:

| Parameter | Description |
|------|---|
|`parentType`| This is the type that contains the field.|
|`field`| The field that the datafetcher is responsible for|

For example, we have the following schema.

```graphql
type Query {
   shows: [Show]
}

type Show {
  title: String
  actors: [Actor]
}
```
We can implement this schema with a single datafetcher.

```java
@DgsComponent
public class ShowDataFetcher {

   @DgsData(parentType = "Query", field = "shows")
   public List<Show> shows() {

       //Load shows from a database and return the list of Show objects
       return shows;
   }
}
```

If the `field` parameter is not set, the method name will be used as the field name.
The `@DgsQuery`, `@DgsMutation` and `@DgsSubscription` annotations are shorthands to define datafetchers on the `Query`, `Mutation` and `Subscription` types.
The following definitions are all equivalent.

```java
@DgsData(parentType = "Query", field = "shows")
public List<Show> shows() { .... }

// The "field" argument is omitted. It uses the method name as the field name.
@DgsData(parentType = "Query")
public List<Show> shows() { .... }

// The parentType is "Query", the field name is derived from the method name.
@DgsQuery
public List<Show> shows() { .... }

// The parentType is "Query", the field name is explicitly specified.
@DgsQuery(field = "shows")
public List<Show> shows() { .... }
```

Notice how a datafetcher can return complex objects or lists of objects.
You don't have to create a separate datafetcher for each field.
The framework will take care of only returning the fields that are specified in the query.
For example, if a user queries:

```graphql
{
    shows {
        title
    }
}
```
Although we're returning Show objects, which in the example contains both a `title` and an `actors` field, the `actors` field gets stripped off before the response gets sent back.

## Child Datafetchers
The previous example assumed that you could load a list of `Show` objects from your database with a single query.
It wouldn't matter which fields the user included in the GraphQL query; the cost of loading the shows would be the same.
What if there is an extra cost to specific fields?
For example, what if loading actors for a show requires an extra query?
It would be wasteful to run the extra query to load actors if the `actors` field doesn't get returned to the user.

In such scenarios, it's better to create a separate datafetcher for the expensive field.

```java
@DgsQuery
public List<Show> shows() {

    //Load shows, which doesn't include "actors"
    return shows;
}

@DgsData(parentType = "Show", field = "actors")
public List<Actor> actors(DgsDataFetchingEnvironment dfe) {

   Show show = dfe.getSource();

   return actorsService.forShow(show.getId());
}
```
The `actors` datafetcher only gets executed when the `actors` field is included in the query.
The `actors` datafetcher also introduces a new concept; the `DgsDataFetchingEnvironment`.
The `DgsDataFetchingEnvironment` gives access to the `context`, the query itself, data loaders, and the `source` object.
The source object is the object that contains the field.
For this example, the source is the `Show` object, which you can use to get the show's identifier to use in the query for actors.

Do note that the `shows` datafetcher is returning a list of `Show`, while the `actors` datafetcher fetches the actors for a single show.
The framework executes the `actors` datafetcher for each `Show` returned by the `shows` datafetcher.
If the actors get loaded from a database, this would now cause an N+1 problem. To solve the N+1 problem, you use [data loaders](data-loaders.md).

Note: There are more complex scenarios with nested datafetchers, and ways to pass context between related datafetchers.
See the [nested datafetchers guide](advanced/context-passing.md) for more advanced use-cases.


## Multiple @DgsData Annotations Via @DgsData.List

Since [v4.6.0], methods can be annotated with multiple `@DgsData` annotations.
Effectively you can resolve multiple GraphQL Type fields via the same method implementation.
To do so you will have to leverage the `@DgsData.List` annotation, for example:

=== "Java"
    ```java
    @DgsData.List({
        @DgsData(parentType = "Query", field = "movies"),
        @DgsData(parentType = "Query", field = "shows")
    })
    ```
=== "Kotlin"
    ```kotlin
    @DgsData.List(
        DgsData(parentType = "Query", field = "movies"),
        DgsData(parentType = "Query", field = "shows")
    )
    ```

Using repeating annotations:

=== "Java"
    ```java
    @DgsData(parentType = "Query", field = "movies")
    @DgsData(parentType = "Query", field = "shows")
    ```

!!! tip
    Both `@DgsQuery` and `@DgsMutation` can't be defined multiple times in a single method. Please use `@DgsData`
    instead and explicitly define the `parentType` to match either `Query` or `Mutation`.


[v4.6.0]: https://github.com/Netflix/dgs-framework/releases/tag/v4.6.0

## Using @InputArgument
It's very common for GraphQL queries to have one or more input arguments. According to the GraphQL specification, an input argument can be:

* An input type
* A scalar
* An enum

Other types, such as output types, unions and interfaces, are not allowed as input arguments.

You can get input arguments as method arguments in a datafetcher method using the `@InputArgument` annotation.

```graphql
type Query {
	shows(title: String, filter: ShowFilter): [Show]
}

input ShowFilter {
   director: String
   genre: ShowGenre
}

enum ShowGenre {
   commedy, action, horror
}
```

We can write a datafetcher with the following signature:
```java
@DgsQuery
public List<Show> shows(@InputArgument String title, @InputArgument ShowFilter filter)
```

The `@InputArgument` annotation will use the name of the method argument to match it with the name of an input argument sent in the query.
Optionally we can specify the `name` argument in the `@InputArgument` annotation, if the argument name doesn't match the method argument name.

The framework converts input arguments to Java/Kotlin types.
The first step for converting input arguments is `graphql-java` using scalar implementations to convert raw string input into whatever type the scalar represents.
A GraphQL `Int` becomes an `Integer` in Java, a formatted date string becomes a `LocalDateTime` (depending on the scalars you're using!), lists become an instance of `java.util.ArrayList`.
Input objects are represented as a `Map<String, Object>` in `graphql-java`.

The next step is the DGS Framework converting the `Map<String, Object>` to the Java/Kotlin classes that you use for the `@InputArgument`.
For Java classes, the framework creates a new instance of the class using the no-arg constructor.
This implies that a no-arg constructor is required.
It then sets each field of the instance to the input argument values.

For Kotlin Data classes, the instance can only be created by passing in all arguments in the constructor.
This means you have to make sure to make fields optional in the data class when the fields are optional in the GraphQL schema!

If you're using the [Codegen](generating-code-from-schema.md) plugin (you really should!), the input types will work perfectly out of the box.

!!!info "Input argument conversion isn't JSON"
    It's easy to confuse the conversion described above with JSON deserialization as you are familiar with in libraries such as Jackson.
    Although it looks similar, the mechanisms are completely unrelated. 
    Input arguments aren't JSON, and the Scalar mechanism is really the core of how conversion works.
    This also means that Jackson annotations on Java/Kotlin types are not used at all. 

!!!info "Defining scalars, and scalars in codegen"
    @InputArgument is designed to work well with scalars.
    More information about defining custom scalars in the framework can be found [here](scalars.md).
    For a scalar you typically either create a class representing the value, or use an existing type. 
    Such types need to be mapped in [Codegen configuration](https://netflix.github.io/dgs/generating-code-from-schema/#mapping-existing-types) so that they don't (incorrectly) get generated.

### Nullability in Kotlin for Input Arguments
If you're using Kotlin you must consider if an input type is nullable.
If the schema defines an input argument as nullable, the code must reflect this by using a nullable type.
If a non-nullable type receives a null value, Kotlin will throw an exception.

For example:

```graphql
# name is a nullable input argument
hello(name: String): String
```
You must write the datafetcher function as:
```kotlin
fun hello(@InputArgument hello: String?)
```

In Java you don't have to worry about this, types can always be null assuming you are using boxed types. 
Generally, we recommend using boxed types instead of unboxed if you are expecting null input.
You do need to null check in your datafetching code for handling possible null inputs.
If using unboxed types, null input will result in exceptions.

### Using @InputArgument with lists
An input argument can also be a list.
If the list type is an input type, you must specify the type explicitly in the `@InputArgument` annotation.

```graphql
type Query {
    hello(people:[Person]): String
}
```

```java
public String hello(@InputArgument(collectionType = Person.class) List<Person> people)

```

### Using Optional with @InputArgument
Input arguments are often defined as optional in schemas.
Your datafetcher code needs to null-check arguments to check if they were provided.
Instead of null-checks you can wrap an input argument in an Optional.

```java
public List<Show> shows(@InputArgument(collectionType = ShowFilter.class) Optional<ShowFilter> filter)
```

You do need to provide the type in the `collectionType` argument when using complex types, similar to using lists.
If the argument is not provided, the value will be `Optional.empty()`.
It's a matter of preference to use `Optional` or not.

## Codegen Constants

In the examples of `@DgsData` so far, we used string values for the `parentType` and `field` arguments.
If you are using [code generation](generating-code-from-schema.md) you can instead use generated constants.
Codegen creates a `DgsConstants` class with constants for each type and field in your schema.
Using this we can write a datafetcher as follows:

```graphql
type Query {
    shows: [Show]
}
```

```java
@DgsData(parentType = DgsConstants.QUERY_TYPE, field = DgsConstants.QUERY.Shows)
public List<Show> shows() {}
```

The benefit of using constants is that you can detect issues between your schema and datafetchers at compile time.

## @RequestHeader, @RequestParam and @CookieValue

Sometimes you need to evaluate HTTP headers, or other elements of the request, in a datafetcher.
You can easily get an HTTP header value by using the `@RequestHeader` annotation.
The `@RequestHeader` annotation is the same annotation as used in Spring WebMVC.
Note that you will need to ensure you are using the webmvc stack for this functionality.

```java
@DgsQuery
public String hello(@RequestHeader String host)
```

Technically, headers are lists of values. If multiple values are set, you can retrieve them as a list by using a List as your argument type. Otherwise, the values are concatenated to a single String.
Similar to `@InputArgument` it's possible to wrap a header or parameter in an `Optional`.

Similarly, you can get request parameters using `@RequestParam`.
Both `@RequestHeader` and `@RequestParam` support a `defaultValue` and `required` argument.
If a `@RequestHeader` or `@RequestParam` is `required`, doesn't have a `defaultValue` and isn't provided, a `DgsInvalidInputArgumentException` is thrown.

To easily get access to cookie values you can use Spring's `@CookieValue` annotation.

```java
@DgsQuery
public String usingCookieWithDefault(@CookieValue(defaultValue = "defaultvalue") myCookie: String) {
    return myCookie
}
```

`@CookieValue` supports a `defaultValue` and the `required` argument.
You can also use an `Optional<String>` for a `@CookieValue` if it's not required.

## Using DgsRequestData to get access to the request object

You can get access to the request object, representing the HTTP request itself, as well.
It's stored on the `DgsContext` object in the `DgsDataFetchingEnvironment`. 

Because Spring WebMVC and Spring Webflux use different types to represent the request, the `DgsRequestData` is different depending on what environment (WebMVC/WebFlux) you're running in.
The `DgsRequestData` interface only gives access to the request headers and the `extensions`.
To get the actual request object, you need to cast the `DgsRequestData` to the correct implementation.
This is either `DgsWebMvcRequestData` or `DgsReactiveRequestData`.
Let's use this in an example to set a cookie, which is done through the response object.

Let's look at a WebMVC example first.
From the `DgsWebMvcRequestData` you can get the `WebRequest`, which can be further cast to a `ServletWebRequest`.

```java
@DgsQuery
@DgsMutation
public String updateCookie(@InputArgument String value, DgsDataFetchingEnvironment dfe) {
    DgsWebMvcRequestData requestData = (DgsWebMvcRequestData) dfe.getDgsContext().getRequestData();
    ServletWebRequest webRequest = (ServletWebRequest) requestData.getWebRequest();
    javax.servlet.http.Cookie cookie = new javax.servlet.http.Cookie("mydgscookie", value);
    webRequest.getResponse().addCookie(cookie);

    return value;
}
```

Now let's try the same with WebFlux.
`DgsRequestData` is now an instance of `DgsReactiveRequestData`, which gives access to the `ServerRequest`.

```java
@DgsMutation
public String updateCookie(@InputArgument String value, DgsDataFetchingEnvironment dfe) {
    DgsReactiveRequestData requestData = (DgsReactiveRequestData) dfe.getDgsContext().getRequestData();
    ServerRequest serverRequest = requestData.getServerRequest();

    serverRequest.exchange().getResponse()
            .addCookie(ResponseCookie.from("mydgscookie", "webfluxupdated").build());
    return value;
}
```

## Using data fetcher context
The `DgsRequestData` object described in the previous section is part of the data fetching _context_.
The DGS Framework adds the `DgsRequestData` to the data fetching context.
You can also add your own data to the context, for use in data fetchers.
The context is initialized per request, before query execution starts.

You can customize the context and add your own data by creating a `DgsCustomContextBuilder`.

```java
@Component
public class MyContextBuilder implements DgsCustomContextBuilder<MyContext> {
    @Override
    public MyContext build() {
        return new MyContext();
    }
}

public class MyContext {
    private final String customState = "Custom state!";

    public String getCustomState() {
        return customState;
    }
}
```

If you require access to the request, e.g. to read HTTP headers, you can implement the `DgsCustomContextBuilderWithRequest` interface instead.

```java
@Component
public class MyContextBuilder implements DgsCustomContextBuilderWithRequest<MyContext> {
    @Override
    public MyContext build(Map<String, Object> extensions, HttpHeaders headers, WebRequest webRequest) {
        //e.g. you can now read headers to set up context
        return new MyContext();
    }
}
```

A data fetcher can now retrieve the context by calling the `getCustomContext()` method:

```java
@DgsData(parentType = "Query", field = "withContext")
public String withContext(DataFetchingEnvironment dfe) {
    MyContext customContext = DgsContext.getCustomContext(dfe);
    return customContext.getCustomState();
}
```

Similarly, custom context can be used in a DataLoader.

```java
@DgsDataLoader(name = "exampleLoaderWithContext")
public class ExampleLoaderWithContext implements BatchLoaderWithContext<String, String> {
    @Override
    public CompletionStage<List<String>> load(List<String> keys, BatchLoaderEnvironment environment) {

        MyContext context = DgsContext.getCustomContext(environment);

        return CompletableFuture.supplyAsync(() -> keys.stream().map(key -> context.getCustomState() + " " + key).collect(Collectors.toList()));
    }
}
```

## Data fetcher threading model

The threading model for data fetchers, concurrent behavior and the use of JDK 21 Virtual threads is [further explained here](advanced/virtual-threads.md).