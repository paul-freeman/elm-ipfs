# Interact with files on IPFS

There are very few file storage options available for Elm which can easily be
incorporated into packages. This package attempts to fix part of this problem by
build file storage on top of the [IPFS HTTP
API](https://docs.ipfs.io/reference/api/http/).

## What you get

Currently, there is only minimal functionality, but even this minimal
functionality should still be quite useful.

Add a string to IPFS:

    helloIpfs : Task Http.Error File
    helloIpfs =
        Ipfs.add "http://127.0.0.1:5001" "Hello planet"

Get the string back from IPFS:

    welcomeIpfs : Task Http.Error String
    welcomeIpfs =
        Ipfs.hash "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG/readme"
            |> Maybe.map (Ipfs.cat "http://127.0.0.1:5001")
            |> Maybe.withDefault (Task.fail Http.BadUrl "bad hash")

# Future

I have plans to add more to this - likely mutable files, and encrypted files.
Stay tuned!