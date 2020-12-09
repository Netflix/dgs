
The [DGS] framework provides a [paved path] for common [GraphQL] use cases.
For most use cases the framework provides annotations to register<!-- http://go/pv --> things such as data fetchers and data loaders.
Besides easing use, the annotation-driven approach also allows us<!-- http://go/we --> to plug in features such as metrics and tracing without the need for extra code.
It is highly recommended that you follow this paved path; if there are any additional requirements, discuss them on [#studio-edge-devex].

However, you can customize the framework in case there are requirements not (yet) supported<!-- http://go/pv --> with higher level concepts.
The framework integrates with [Spring Boot], and follows the auto-configuration mechanism that Spring uses.
This allows a developer to plug in certain aspects to the framework, or to completely replace components provided by the framework.
The [`DgsAutoConfiguration`](https://stash.corp.netflix.com/projects/PX/repos/domain-graph-service-java/browse/graphql-dgs-spring-boot-autoconfigure/src/main/kotlin/com/netflix/graphql/dgs/autoconfig/DgsAutoConfiguration.kt) class is responsible for auto configuration.
The framework defines each component with the following annotations:

```
@Bean
@ConditionalOnMissingBean
```

This means that if you provide your own bean of the same type, the framework will use your instance instead of creating the default one.
This way, you can customize any of the components created by the framework.

If you find reasons to customize the framework, please let the Studio Edge Developer Experience team know at [#studio-edge-devex], so that they can help you to configure things correctly, and also explore if better alternatives can be provided by the framework.

--8<-- "docs/reference_links"

