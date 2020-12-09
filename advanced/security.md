
By default a [Gandalf] policy protects every [DGS].
This policy only allows access via [GraphQL] for employees.
This prevents accidental exposure of data to the outside world via the [Studio Edge Gateway].
The Gandalf policy is checked<!-- http://go/pv --> for each incoming request.
If the policy check fails a 403 is returned<!-- http://go/pv -->.

The default Gandalf policy is `studio-edge-dgs-default`.
You can see the details of the policy [here](https://portal.gandalf.netflix.net/policy/detail/studio-edge-dgs-default).
It includes the following users:

* all-netflix-employees

This is a safe default, but for many Studio use cases it is not sufficient.
For example, contractors may need access to the data, or you require finer control for specific fields in the graph.
The framework makes it easy to specify your own policies both on a coarse- and a fine-grained level.

## Creating Your Own Policy

To change the coarse-grained check, [create](http://manuals.netflix.net/view/gandalf/mkdocs/master/policy_guidelines/) your own [Gandalf] policy.
Once you create the policy, hook it up to the [DGS] framework by adding the following configuration in `application.yml`:

```yaml
dgs:
  security:
    policyname: your-gandalf-policy
```

## Fine-grained Access Control with @Secured

To establish fine-grained access control on data fetchers, apply the standard Spring `@Secured` annotation.
This allows stricter checks for specific fields in the graph.

```java
@DgsComponent
public class SecurityExampleFetchers {
    @DgsData(parentType = "Query", field = "hello")
    public String hello() {
        return "Hello to everyone passing the coarse grained policy";
    }      

    @Secured("studio-edge-dgs-examples-deny")
    @DgsData(parentType = "Query", field = "deny")
    public String deny() {
        return "this shouldn't show";
    }

    @Secured("studio-edge-dgs-users")
    @DgsData(parentType = "Query", field = "secureGroup")
    public String secureGroup() {
        return "Only for users in studio-edge-dgs-users";
    }
}
```

This works the same as for [gRPC] and REST in Spring, including role mappings.
See [Spring Reference: Security and Secrets: @Secured Access Control](http://manuals.netflix.net/view/runtime-java/mkdocs/master/spring-reference/security/security-and-secrets/#secured-access-control).

Note that a policy in `@Secured` can only enforce stricter control; it cannot loosen such control.
A request first goes through the coarse-grained checks before it even checks the data fetchers.

!!!caution
    The `@Secured` annotation will not protect a function that is called by another unsecured function within the same class.
    In other words, if `foo()` calls `@Secured bar()` but `foo()` is *not* marked `@Secured`, the security will not be applied to `bar()` during that call either.

    `@Secured` also fails to work for data loaders.
    As a workaround, you can use<!-- http://go/use --> `SsoCaller` in data loaders.

## Programmatic Access Control

A [DGS] is just a [Spring Boot] app, so you can still use the security integration Netflix has for any Spring Boot app.
An example is injecting the `SsoCaller` to get information about the calling user/app:

```java
@DgsComponent
public class HelloDataFetcher {

    @Autowired
    SsoCallerResolver ssoCallerResolver;

    @DgsData(parentType = "Query", field = "hello")
    public String hello(DataFetchingEnvironment dfe) {

        //Note that these values are all optionals, e.g. different fields are there for Metatron calls!
        String fullname = ssoCallerResolver.get().getUser().get().getFullName().get();
        return "Hello, " + fullname;
    }
}
```

More documentation can be found in [Spring Reference: Security and Secrets: SsoCaller Usage](https://manuals.netflix.net/view/runtime-java/mkdocs/master/spring-reference/security/security-and-secrets/#ssocaller-usage).

## Testing with Security

[Query testing](../../testing/security-testing.md) with `@Secured` is easy too.
By default, tests ignore the `@Secured` annotation while unit testing, so no additional setup is required.
If you want to test SSO features specifically (for example if your data fetcher relies on SSO features), [Spring Boot] has excellent [support](https://manuals.netflix.net/view/runtime-java/mkdocs/master/spring-reference/security/testing_with_security/) for doing so.
The following example [DGS] test tests if an `@Secured` data fetcher only allows requests from users in the correct group.

```java
@SpringBootTest(classes = {SecurityExampleFetchers.class, DgsAutoConfiguration.class})
@EnableSsoTest
public class SecureDataFetcherTest {
    @Autowired
    DgsQueryExecutor queryExecutor;

    @Test
    @WithSsoUser(name = "validuser", gandalfPolicies = "studio-edge-dgs-users")
    public void testSecureWithValidUser() {
        ExecutionResult executionResult = queryExecutor.execute("{secureGroup}");
        assertNotNull(executionResult);
        assertTrue(executionResult.isDataPresent());
        assertEquals(0, executionResult.getErrors().size());
    }

    @Test
    @WithSsoUser(name = "invaliduser")
    public void testSecured() {
        ExecutionResult executionResult = queryExecutor.execute("{secureGroup}");
        assertNotNull(executionResult);
        assertEquals(1, executionResult.getErrors().size());
        assertEquals("org.springframework.security.access.AccessDeniedException: Access is denied", executionResult.getErrors().get(0).getMessage());
    }
}
```
 
## Switching Off Gandalf

To completely switch off [AuthZ], you can use the following configuration:

```yaml
dgs:
  security:
    disabled: true
```

--8<-- "docs/reference_links"

