
It is easy to add a custom scalar type in the DGS framework:
Create a class that implements the `graphql.schema.Coercing` interface and annotate it with the `@DgsScalar` annotation.
Also make sure the scalar type is defined in your [GraphQL] schema!

For example, this is a simple `LocalDateTime` implementation:

```java
@DgsScalar(name="DateTime")
public class DateTimeScalar implements Coercing<LocalDateTime, String> {
    @Override
    public String serialize(Object dataFetcherResult) throws CoercingSerializeException {
        if (dataFetcherResult instanceof LocalDateTime) {
            return ((LocalDateTime) dataFetcherResult).format(DateTimeFormatter.ISO_DATE_TIME);
        } else {
            throw new CoercingSerializeException("Not a valid DateTime");
        }
    }

    @Override
    public LocalDateTime parseValue(Object input) throws CoercingParseValueException {
        return LocalDateTime.parse(input.toString(), DateTimeFormatter.ISO_DATE_TIME);
    }

    @Override
    public LocalDateTime parseLiteral(Object input) throws CoercingParseLiteralException {
        if (input instanceof StringValue) {
            return LocalDateTime.parse(((StringValue) input).getValue(), DateTimeFormatter.ISO_DATE_TIME);
        }

        throw new CoercingParseLiteralException("Value is not a valid ISO date time");
    }
    
    @Override
    public Value valueToLiteral(@NotNull Object input) {
        return new StringValue(this.serialize(input));
    }
}
```

**Schema:**
```graphql
scalar DateTime
```


!!! important
    If you are [Building GraphQL Queries for Tests](./query-execution-testing.md), make sure to pass your custom scalars in
    `GraphQLQueryRequest` constructor as descibred in [Scalars in DGS Client](./advanced/java-client.md)



## Registering Custom Scalars

In more recent versions of `graphql-java` (>v15.0) [some scalars](https://github.com/graphql-java/graphql-java-extended-scalars),
most notably the `Long` scalar, are no longer available by default.
These are non-standard scalars that are difficult for clients (e.g. JavaScript) to handle reliably.
As a result of the deprecation, you will need to add them explicitly, and to do this you have a few options.

!!! tip
    Go to the [graphql-java-extended-scalars project page](https://github.com/graphql-java/graphql-java-extended-scalars)
    to see the full list of scalars supported by this library. There you will also find examples of the scalars used
    in both _schemas_ as well as example queries.

### Automatically Register Scalar Extensions via graphql-dgs-extended-scalars

The DGS Framework, as of version 3.9.2, has the `graphql-dgs-extended-scalars` module. This module provides an
_auto-configuration_ that will register automatically the scalar extensions defined in the
`com.graphql-java:graphql-java-extended-scalars` library. To use it you need to...

1. Add the `com.netflix.graphql.dgs:graphql-dgs-extended-scalars` dependency to your build. If you are using the
   [DGS BOM] you don't need to specify a version for it, the BOM will recommend one.
1. Define the scalar in your schema


Other mapping available on [extended scalars doc](https://github.com/graphql-java/graphql-java-extended-scalars)

The `graphql-java-extended-scalars` module offers a few knobs you can use to turn off registration.


| Property                                          | Description |
| ------------------------------------------------- | ----------- |
| dgs.graphql.extensions.scalars.time-dates.enabled | If set to `false`, it will not register the DateTime, Date, and Time scalar extensions.           |
| dgs.graphql.extensions.scalars.objects.enabled    | If set to `false`, it will not register the Object, Json, Url, and Locale scalar extensions.      |
| dgs.graphql.extensions.scalars.numbers.enabled    | If set to `false`, it will not register all numeric scalar extensions such as PositiveInt, NegativeInt, etc.|
| dgs.graphql.extensions.scalars.chars.enabled      | If set to `false`, it will not register the GraphQLChar extension. |
| dgs.graphql.extensions.scalars.enabled            | If set to `false`, it will disable automatic registration of all of the above. |


!!! important
    Are you using the [code generation Gradle Plugin](generating-code-from-schema.md)?

    The `graphql-java-extended-scalars`  module doesn't modify the behavior of such plugin,
    you will need to explicit define the _type mappings_.
    For example, let's say we want to use both the `Url` and `PositiveInt` Scalars.
    You will have to add the mapping below to your build file.
    === "Gradle"
        ```groovy
        generateJava {
            typeMapping = [
                "Url" : "java.net.URL",
                "PositiveInt" : "java.lang.Integer"
            ]
        }
        ```
    === "Gradle Kotlin"
        ```kotlin
        generateJava {
            typeMapping = mutableMapOf(
                "Url" to "java.net.URL",
                "PositiveInt" to "java.lang.Integer"
            )
        }
        ```

### Testing in Java using `graphql-dgs-extended-scalars`
Don't forget to provide `DgsExtendedScalarsAutoConfiguration.class` when testing.

```java
@SpringBootTest(classes = {DgsAutoConfiguration.class, DgsExtendedScalarsAutoConfiguration.class})
class Test {
...
```

### Register Scalar Extensions via DgsRuntimeWiring

You can also register the Scalar Extensions manually. To do so you need to...

1. Add the `com.graphql-java:graphql-java-extended-scalars` dependency to your build. If you are using the
   [DGS BOM] you don't need to specify a version for it, the BOM will recommend one.
1. Define the scalar in your schema
1. Register the scalar.

Here is an example of how you would set that up:

**Schema:**
```graphql
scalar Long
```
You can register the `Long` scalar manually with the DGS Framework as shown here:
```java
@DgsComponent
public class LongScalarRegistration {
    @DgsRuntimeWiring
    public RuntimeWiring.Builder addScalar(RuntimeWiring.Builder builder) {
        return builder.scalar(Scalars.GraphQLLong);
    }
}
```


[DGS BOM]: ./advanced/platform-bom.md
