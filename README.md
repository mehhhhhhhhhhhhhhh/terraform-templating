Templating support for Terraform / [OpenTofu](https://github.com/mehhhhhhhhhhhhhhh/opentofu-templating)
=======


An example
-------

The elusive dynamic backend/provider configuration -- at the time of writing, still [impossible](https://github.com/hashicorp/terraform/issues/13022) in Terraform after many years; [maybe coming](https://github.com/opentofu/opentofu/issues/300) in OpenTofu 1.9.

With the tool in this repo, it's just as trivial to do as any other variation:

```erb
provider "aws" {
  region  = "<%= Environment['region'] %>"
  version = "~> 4.23.0"
}

<%
terraform_state_bucket_name =
  Environment['production_account'] ?
      "terraform-state.#{Environment['region']}.#{Environment['production_account']}.example.com"
    : 'terraform-state.dev.example.com'
%>

terraform {
  required_providers {
    aws = "~> 4.23.0"
  }
  backend "s3" {
    bucket = "<%= terraform_state_bucket_name %>"
    key    = "terraform-<%= TerraformVersion %>-aws-4.23-main.tfstate"
    region = "<%= Environment['production_account'] ? Environment['region'] : 'us-west-2' %>"
  }
}

```

This is an example of the ERB format (`.tf.erb`). ERB is a templating language like Jinja or PHP(!), except based on Ruby (and provided in Ruby's standard library).

For `resource` and `data` declarations, we also have the option of a simple **Ruby DSL** (domain-specific language).

In the example above, the template contains references to **external configuration** for the `Environment` (workspace) being worked on.

* More of this type of code, including the Ruby DSL (`.tf.rb`), can be seen in [`examples/with-env-data`](examples/with-env-data).
* The sample config files it's using can be seen in [`example-data`](example-data).
* In this directory, the `./plan` script is a symlink to [`lib/terraform-templating/plan-with-env-data`](lib/terraform-templating/plan-with-env-data).

This is not strictly necessary -- the templating tool can also be used by itself, **without the need for any external files** at all.

* This type of code, directly referencing a local JSON file for code generation, can be seen in [`examples/standalone`](examples/standalone).
* In this example directory, the `./plan` script is a symlink to [`lib/terraform-templating/plan-standalone`](lib/terraform-templating/plan-standalone).


How to get started
-------

Clone [`lib/terraform-templating`](lib/terraform-templating) somewhere.

Create a symlink (in this example, called `plan`) to the [`plan-standalone`](lib/terraform-templating/plan-standalone) script in that directory, from your Terraform directory.

Use this `./plan` link instead of directly calling Terraform, and a `work/` subdirectory will be created with the evaluated template results, and links to all your other original files. Then, terraform will be called in that directory instead of your original directory.

To **test template evaluation without calling Terraform**, just call `./plan -t` and the `work/` directory will be created without calling any command.

Just `./plan` by default will run `terraform plan -out result.plan | tee result.planning`. Both of these files will end up in the `work/` directory.

Then, `./plan -- apply result.plan` will pick up that `result.plan` file, since it also calls Terraform from that same `work/` directory.

The `result.planning` file is sometimes useful if you want to review the results of the plan later, or compare them with other results.

You can run any other Terraform command within the `work/` directory in the same way, by passing it to `./plan` instead of `apply`:

* `./plan -- workspace new potato`
* `./plan -- import aws_instance.thing i-0123456789`


Other variations
-------

This isn't a framework -- it's just an example, which can be easily modified for different needs. You should own your own interface!

Check out the repo, and compare the changes from `plan-standalone` to `plan-with-env-data` in [`lib/terraform-templating`](lib/terraform-templating) -- you'll see that the customization needed is pretty minimal, to get similar results with your own project layout.


Hidden depths
-------

* The `with-env-data` example, since it uses a different directory for each generated environment, also allows multiple environments' plans to be run concurrently without any trouble.

* Each working directory gets symlinked to a single copy of the Terraform plugins / providers, which ends up in the `lib` directory next to the source script.
