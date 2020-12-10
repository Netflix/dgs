
In GraphQL, you model a file upload operation as a GraphQL mutation request from a client to your DGS.

The following sections describe how you implement file uploads and downloads using a Multipart POST request.
For more context on file uploads and best practices, see [Apollo Server File Upload Best Practices](https://www.apollographql.com/blog/apollo-server-file-upload-best-practices-1e7f24cdc050) by Khalil Stemmler from *Apollo Blog*.
    

## Multipart File Upload

A multipart request is an HTTP request that contains multiple parts in a single request: the mutation query, file data, JSON objects, and whatever else you like.
You can use Apollo’s upload client, or even a simple cURL, to send along a stream of file data using a multipart request that you model in your schema as a Mutation.

![File uploads with multipart](../images/file-upload-multipart.png#center)


See [GraphQL multipart request specification](https://github.com/jaydenseric/graphql-multipart-request-spec) for the specification of a multipart `POST` request for uploading files using GraphQL mutations.

The DGS framework supports the `Upload` scalar with which you can specify files in your mutation query as a `MultipartFile`.
When you send a multipart request for file upload, the framework processes each part and assembles the final GraphQL query that it hands to your data fetcher for further processing.

Here is an example of a Mutation query that uploads a file to your DGS:

```graphql
scalar Upload

extend type Mutation  {
    uploadScriptWithMultipartPOST(input: Upload!): Boolean
}
```

Note that you need to declare the `Upload` scalar in your schema, although the implementation is provided by the DGS framework.
In your DGS, add a data fetcher to handle this as a `MultipartFile` as shown here:

```java
@DgsData(parentType = DgsConstants.MUTATION.TYPE_NAME, field = "uploadScriptWithMultipartPOST")
    public boolean uploadScript(DataFetchingEnvironment dfe) throws IOException {
        // NOTE: Cannot use @InputArgument  or Object Mapper to convert to class, because MultipartFile cannot be
        // deserialized
        MultipartFile file = dfe.getArgument("input");
        String content = new String(file.getBytes());
        return ! content.isEmpty();
    }

```

Note that you will not be able to use a Jackson object mapper to deserialize a type that contains a `MultipartFile`, so you will need to explicitly get the file argument from your input.

On your client, you can use `apollo-upload-client` to send your Mutation query as a multipart `POST` request with file data.
Here’s how you configure your link:

```javascript
import { createUploadLink } from 'apollo-upload-client'

const uploadLink = createUploadLink({ uri: uri })

const authedClient = authLink && new ApolloClient({
        link: uploadLink)),
        cache: new InMemoryCache()
})
```

Once you set this up, set up your Mutation query and the pass the file that the user selected as a variable:

```javascript
// query for file uploads using multipart post
const UploadScriptMultipartMutation_gql = gql`
  mutation uploadScriptWithMultipartPOST($input: Upload!) {
    uploadScriptWithMultipartPOST(input: $input)
  }
`;

function MultipartScriptUpload() {
  const [
    uploadScriptMultipartMutation,
    {
      loading: mutationLoading,
      error: mutationError,
      data: mutationData,
    },
  ] = useMutation(UploadScriptMultipartMutation_gql);
  const [scriptMultipartInput, setScriptMultipartInput] = useState<any>();

  const onSubmitScriptMultipart = () => {
    const fileInput = scriptMultipartInput.files[0];
    uploadScriptMultipartMutation({
      variables: { input: fileInput },
    });
  };

  return (
    <div>
      <h3> Upload script using multipart HTTP POST</h3>
      <form
        onSubmit={e => {
          e.preventDefault();
          onSubmitScriptMultipart();
        }}>
        <label>
          <input
            type="file"
            ref={ref => {
              setScriptMultipartInput(ref!);
            }}
          />
        </label>
        <br />
        <br />
        <button type="submit">Submit</button>
      </form>
    </div>
  );
}
```
--8<-- "docs/reference_links"

