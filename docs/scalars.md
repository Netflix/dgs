
It is easy to add a custom scalar type in the [DGS] framework:
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
}
```

**Schema:**
```graphql
scalar DateTime
```
## Registering Custom Scalars
In more recent versions of `graphql-java` (>v15.0), some scalars, most notably, the `Long` scalar are no longer available by default. 
These are non standard scalar that is difficult for clients (e.g. JavaScript) to handle reliably.
As a result of the deprecation,  you will need to 1) Define the scalar in your schema, and 2) Register the scalar.

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
