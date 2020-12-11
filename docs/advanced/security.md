## Fine-grained Access Control with @Secured

The DGS Framework integrates with Spring Security using the well known `@Secured` annotation.
Spring Security itself can be configured in many ways, which goes beyond the scope of this documentation.
Once Spring Security is set up however, you can apply `@Secured` to your data fetchers, very similarly to how you apply it to a REST Controller in Spring MVC.

```java
@DgsComponent
public class SecurityExampleFetchers {
    @DgsData(parentType = "Query", field = "hello")
    public String hello() {
        return "Hello to everyone";
    }      

    @Secured("admin")
    @DgsData(parentType = "Query", field = "secureGroup")
    public String secureGroup() {
        return "Hello to admins only";
    }
}
```
