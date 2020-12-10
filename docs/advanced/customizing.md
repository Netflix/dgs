
The DGS framework provides a paved path for common GraphQL use cases.
For most use cases the framework provides annotations to register<!-- http://go/pv --> things such as data fetchers and data loaders.

You can also customize the framework in case there are requirements not (yet) supported<!-- http://go/pv --> with higher level concepts.
The framework integrates with [Spring Boot], and follows the auto-configuration mechanism that Spring uses.
This allows a developer to plug in certain aspects to the framework, or to completely replace components provided by the framework.
The [`DgsAutoConfiguration`](https://github.com/Netflix/dgs-framework/blob/master/graphql-dgs-spring-boot-oss-autoconfigure/src/main/kotlin/com/netflix/graphql/dgs/autoconfig/DgsAutoConfiguration.kt) class is responsible for auto configuration.
The framework defines each component with the following annotations:

```
@Bean
@ConditionalOnMissingBean
```

This means that if you provide your own bean of the same type, the framework will use your instance instead of creating the default one.
This way, you can customize any of the components created by the framework.

--8<-- "docs/reference_links"

