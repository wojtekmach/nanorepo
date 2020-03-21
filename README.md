# NanoRepo

Minimal self-hosting for Hex packages.

## Usage

Install with:

    $ mix escript.install github wojtekmach/nanorepo

Command line usage:

    $ nanorepo
    Usage:

      nanorepo init REPO

        Prepares repository hosting for REPO in the current directory.
        You may initialize multiple different repositories in the same base directory.

      nanorepo init.mirror REPO hexpm

        Prepares mirror for hex.pm as REPO in the current directory.

      nanorepo init.mirror REPO MIRROR_REPO_NAME MIRROR_URL MIRROR_PUBLIC_KEY_PATH

        Prepares mirror for MIRROR_REPO_NAME as REPO in the current directory.

        A mirror is a read-through cache for the given MIRROR_URL. `nanorepo init.mirror`
        just fetches and stores `/names` and `/versions` registry index files,
        all the other files would be read on-demand. To enable the read-through cache,
        pass `--mirror` to `nanorepo serve`.

      nanorepo publish REPO TARBALL_PATH

        Publishes TARBALL_PATH to REPO.

      nanorepo rebuild REPO

        Rebuilds the given REPO from it's stored tarballs.

      nanorepo serve [--port PORT --mirror MIRROR]

        Serves files stored in `public/` for repositories initialized in the current
        directory.

        Options:

          * `--port` - defaults to 4000.
          * `--mirror` - the name of the mirror that was initialized with `init.mirror`.
            This option may be given multiple times to support multiple mirrors.

### Example 1: Create a private repo, add a package, and use it from a Mix project

    $ mkdir playground
    $ cd playground
    $ nanorepo init acme
    $ curl -O https://repo.hex.pm/tarballs/hex_core-0.6.8.tar
    $ nanorepo publish acme hex_core-0.6.8.tar
    $ nanorepo serve

In another terminal:

    $ mix hex.repo add acme http://localhost:4000/acme --public-key /path/to/playground/acme_public_key.pem
    $ mix new example
    $ cd example

Add the following to your `mix.exs`:

    {:hex_core, "~> 0.6.0", repo: "acme"}

Finally, run:

    $ mix deps.get

The package should be downloaded from your local web server in the first terminal tab.

### Example 2: Create a private repo, add a package, and use it from a Rebar project

    $ mkdir playground
    $ cd playground
    $ nanorepo init acme
    $ curl -O https://repo.hex.pm/tarballs/hex_core-0.6.8.tar
    $ nanorepo publish acme hex_core-0.6.8.tar
    $ nanorepo serve

Add the following to `~/.config/rebar3/rebar.config`:

```erlang
{plugins, [rebar3_hex]}.
{hex, [
  {repos, [
    #{
      name => <<"acme">>,
      repo_url => <<"http://localhost:4000/acme">>,
      repo_public_key => <<"">> %% get from /path/to/playground/acme_public_key.pem
    }
  ]}
]}.
```

In another terminal:

    $ rebar3 new lib example

Add the following to your `rebar.config`:

    {erl_opts, [debug_info]}.
    {deps, [
      {hex_core, "0.6.8"}
    ]}.

Finally, run:

    $ rebar3 deps

The package should be downloaded from your local web server in the first terminal tab.

### Example 3: Create a private repo, add a package, and sync it with S3

First, create a bucket on S3. By default, the files stored on S3 are not publicly accessible.
You can enable public access by setting the following bucket policy in your
bucket's properties:

```json
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "AllowPublicRead",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::nanorepo/*"
        }
    ]
}
```

See AWS S3 documentation for more information, especially around making this secure.

Now, let's install [AWS CLI](https://aws.amazon.com/cli/).

Finally, set up nanorepo, publish a package, and sync the repo with S3

    $ mkdir playground
    $ cd playground
    $ nanorepo init acme
    $ curl -O https://repo.hex.pm/tarballs/hex_core-0.6.8.tar
    $ aws s3 sync public/acme s3://nanorepo

### Example 4: Create a Hex.pm mirror

    $ mkdir playground
    $ cd playground
    $ nanorepo init.mirror mymirror hexpm
    $ nanorepo server --mirror mymirror
    $ curl -O http://localhost:4000/mymirror/tarballs/hex_core-0.6.8.tar

## License

Copyright (c) 2020 Wojciech Mach

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
