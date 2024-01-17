
In scenarios where a custom object mapper is required, you can customize Spring's underlying object mapper. 
However, note that this will affect the behavior for all usages of the mapper, and therefore should be done carefully.
Also, this mechanism will NOT affect how custom scalars are serialized - those would rely on your scalar implementation's serialization logic handled by `graphql-java`

```java
@Bean
public Jackson2ObjectMapperBuilder jackson2ObjectMapperBuilder() {
    return new Jackson2ObjectMapperBuilder().serializers(LOCAL_DATETIME_SERIALIZER).serializationInclusion(JsonInclude.Include.NON_NULL);
}
```



