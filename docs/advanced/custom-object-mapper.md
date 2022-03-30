
In certain applications, you may want to customize the serialization of the GraphQL response, for e.g., by adding additional modules.
This can be done by setting up a custom object mapper that overrides the default provided by the DGS framework in your application's configuration class.
Note that this mapper is only used for serialization of outgoing GraphQL responses.
Also, this mechanism will NOT affect how custom scalars are serialized - those would rely on your scalar implementation's serialization logic handled by `graphql-java`

To create a custom object mapper, implement a Spring bean of type `ObjectMapper` with `@Qualifier("dgsObjectMapper")`.

```java
@Bean
  @Qualifier("dgsObjectMapper")
  open fun dgsObjectMapper(): ObjectMapper {
    val customMapper = jacksonObjectMapper()
    customMapper.registerModule(JavaTimeModule())
    return customMapper
}
```

