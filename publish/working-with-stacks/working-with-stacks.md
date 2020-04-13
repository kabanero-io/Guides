---
permalink: /guides/working-with-stacks/
layout: guide-markdown
title: Customizing application stacks
duration: 40 minutes
releasedate: 2020-02-06
description: Learn how to create, update, build, test, and publish application stacks
tags: ['stack', 'Node.js']
guide-category: basic
---


<!-- Note:
> This repository contains the guide documentation source. To view
> the guide in published form, view it on the [website](https://kabanero.io/guides/{projectid}.html).
-->

<!--
//	Copyright 2020 IBM Corporation and others.
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.
-->

## What you'll learn

In this guide you will learn how to create a new application stack for use in your organization. Then you'll learn how to customize it and publish it to a
GitHub repository for developers to use in their local development environment. Finally you'll learn how to configure your Kubernetes custom resource definition (CRD) to initialize and deploy the containerized applications that are developed.  

## Prerequisites

- [Docker](https://docs.docker.com/get-started/) must be installed.
- [Appsody](https://appsody.dev/docs/getting-started/installation) must be installed.
(Optional) To deploy your customized stack, you must have access to the OpenShift Container Platform (OCP) v4.3 cluster.

## Getting started

Application stacks are stored in Git repositories. How you organize the applications stacks that you intend to use in your organization is entirely up to you and might depend on a number of local requirements. For example, using a different repository for each stack gives you the flexibility to apply version control at the individual stack level. The important part to understand is that each repository you create results in a unique configuration file that a developer might use for accessing any stacks that are stored there.  

In this guide we'll assume that you are interested in using an application stack for Javascript development with the Node.js Express framework. You've taken a look at the Node.js Express application stack, which you want to use as the basis for a local customized stack.

## Cloning an existing stack

To create an application stack based on Appsody `nodejs-express`, run the following command:

`appsody stack create my-nodejs-express-stack --copy incubator/nodejs-express`

Where `my-nodejs-express-stack` is the name you give your application stack.

A new `my-nodejs-express-stack` directory is created that is based on the originating stack, which contains the following key files and directories:

- `README.md`
    Contains detailed information about the stack and the available templates. Use this file to record any unique aspects of your stack for users.
- `stack.yaml`
    Contains the basic definition for the stack. Here you can uniquely identify your stack, configure the default template that is used when you initialize a project, or control the versions of software components that can be used with the stack, including the Appsody CLI.
- `image/config/app-deploy.yaml`
    Contains configuration information that is used by an operator for deploying a project to Kubernetes or serverless.
- `image/project/Dockerfile-stack`
    Creates a stack image that is used to generate a development container. You can modify environment variables in the `Dockerfile-stack` file that change the container environment for local development. For example, you can adjust the mount points for local application code, update the files or directories that are monitored for source code changes, and configure the caching of software dependencies. These dependencies are stored in volumes that can be mounted
    when a development container is restarted to reduce the startup time.
- `image/project/Dockerfile`
    Creates the final image that is used to generate the deployment container.
- `templates/simple/`
    Files in this folder comprise a simple starter Express application and a sample test.
- `templates/scaffold/`
    Files in this folder comprise a more complex Express application with routes and views.

You can add or remove template directories to provide different starting points for developers.

In addition to updating the files in your stack directory, you can also set file permissions to prevent user making further changes to them.


## Updating a stack

Although there are many aspects that you can modify for an application stack, in this guide we will make a very simple change. Edit the `stack.yaml` definition file to change the default template from `simple` to `scaffold`:


```
name: Node.js Express
version: 0.4.1
description: Express web framework for Node.js
license: Apache-2.0
language: nodejs
maintainers:
  - name: Sam Roberts
    email: vieuxtech@gmail.com
    github-id: sam-github
default-template: scaffold
requirements:
  docker-version: ">= 17.09.0"
  appsody-version: ">= 0.2.7"
  ```

Save your changes.

When you've configured a stack to suit your requirements, it must be packaged before it can be used for application development.

## Packaging a stack

From the `my-nodejs-express-stack` directory, run the following command:

```
appsody stack package
```

This command builds the image and creates archive files for any source code and templates that you've included. These are stored in a `.appsody/stacks/dev.local` directory and your stack is then added to the `dev.local` repository.

To view the stack in your repository, run:

```
appsody repo list
```

The output is similar to the following example:

```
NAME            URL
*incubator      https://github.com/appsody/stacks/releases/latest/download/incubator-index.yaml
dev.local       file:///$HOME/.appsody/stacks/dev.local/dev.local-index.yaml
experimental    https://github.com/appsody/stacks/releases/latest/download/experimental-index.yaml
```

The asterisk (\*) indicates the default repository. To make `dev.local` your default, run:

```
appsody repo set-default dev.local
```

Now run the following command to check that the stack you packaged is showing in the repository:

```
appsody list dev.local
```

The output should be similar to the following example:

```
REPO     	ID                    	VERSION  	TEMPLATES        	DESCRIPTION                      
dev.local	my-nodejs-express-stack	0.4.1    	*scaffold, simple	Express web framework for Node.js
```

The asterisk (\*) indicates the default template. Your stack updates were a success!

## Testing your stack

The first check is to validate your stack by running the following command:

```
appsody stack validate
```

The validation process steps through a number of test operations that check the structure of your
application stack before packaging and initializing a project. The project is then run and tested against any generic tests that are defined in stack. Finally a production image is generated for
deployment. A summary of the results is printed, similar to the  following example output:

```
@@@@@@@@@@@@@@@ Validate Summary Start @@@@@@@@@@@@@@@@
PASSED: Lint for stack:my-nodejs-express-stack
PASSED: Package for stack:my-nodejs-express-stack
PASSED: Init for stack:my-nodejs-express-stack template:simple
PASSED: Run for stack:my-nodejs-express-stack template:simple
PASSED: Test for stack:my-nodejs-express-stack template:simple
PASSED: Build for stack:my-nodejs-express-stack template:simple
PASSED: Init for stack:my-nodejs-express-stack template:scaffold
PASSED: Run for stack:my-nodejs-express-stack template:scaffold
PASSED: Test for stack:my-nodejs-express-stack template:scaffold
PASSED: Build for stack:my-nodejs-express-stack template:scaffold
Total PASSED: 10
Total FAILED: 0
@@@@@@@@@@@@@@@  Validate Summary End  @@@@@@@@@@@@@@@@
```

The next step is to test the changes you made to the stack. In this guide, the changes are very minor and can be checked very easily by initializing a project from the application stack.

Run the following command:

```
appsody init my-nodejs-express-stack
```

You see output similar to the following example:

```
...
Checking stack requirements...
Docker requirements met
Appsody requirements met
Running appsody init...
Downloading my-nodejs-express-stack template project from file:///Users/user1/.appsody/stacks/dev.local/my-nodejs-express.v0.4.1.templates.scaffold.tar.gz
Download complete. Extracting files from /Users/user1/appsody/my-nodejs-express/test/my-nodejs-express.tar.gz
Setting up the development environment
Your Appsody project name has been set to test
Using local cache for image dev.local/appsody/my-nodejs-express:0.4
Running command: docker run --rm --entrypoint /bin/bash dev.local/appsody/my-nodejs-express:0.4 -c find /project -type f -name .appsody-init.sh
Successfully initialized Appsody project with the my-nodejs-express-stack stack and the default template.
```

When you view the contents of your project folder you can see the `routes` and `views` directories, which are only included in the `scaffold` template.

Major changes to the stack will require more detailed testing before your stack is ready to be released.

## Releasing your stack

Now that your stack is available in your local repository, the next step is to release your stack and make the artifacts available to other users. Follow these steps:

1. Push the stack container image to a registry, such as docker.io.
2. Upload the source code and archives from your `.appsody/stacks/dev.local` directory to a web hosting service, such as a GitHub repository. The example in this guides uses the repository `my-org-repository` in the `myorg` organization (https://github.com/myorg/my-org-repository).
3. Create a draft GitHub release for your stack, which places the source code and archives into a download folder. See [Creating releases](https://help.github.com/en/github/administering-a-repository/creating-releases).
4. From the top level directory of your stack, run the following command to add your stack to the `my-org-repository` repository, referencing the release URL:

    ```
    appsody stack add-to-repo my-org-repository --release-url https://github.com/myorg/my-org-repository/releases/latest/download/
    ```

    The output from this command is similar to the following example:

    ```
    ******************************************
    Running appsody stack add-to-repo
    ******************************************
    Creating repository index file: /Users/user1/.appsody/stacks/dev.local/my-org-repository-index.yaml
    Repository index file updated successfully
    ```

5. Upload the repository index file that is created in your `.appsody/stacks/dev.local` directory to your GitHub repository. Add it to your draft release and then publish the release.


Now that you have released your application stack you can share your URL for the index file with developers. Developers must configure their local development environment to access the stack in one of the following ways:

  - Developers who are using the CLI from the Appsody project can add it to their local repository list with the `appsody repo add` command. For more information, see [Developing microservice applications with the CLI](../use-appsody-cli/)
  - Developers who are using an IDE with the Eclipse Codewind extension can configure their template sources. For more information, see [Getting Started with Codewind and VSCode](../codewind-getting-started-vscode/) or [Getting Started with Codewind and Eclipse](../codewind-getting-started-eclipse/).

Developers can now create applications based on your customized stack in their local development environment. If you plan to make more than one  application stack available to developers, you might want to consider creating a stack hub. For more information, see [Creating a stack hub](../creating-a-stack-hub/).

## Configuring your Kubernetes environment

In order to deploy containerized applications that have been developed using your application stack, you must configure Kubernetes with information about the application stack and the deployment container that must be used. This configuration forms part of the Kabanero operator custom resource definition (CRD). The process is the same whether your URL defines a single application stack or a stack hub that contains multiple application stacks.

Follow these steps:

1. Obtain a copy of your current Kabanero CR instance configuration.

    To obtain a list of all Kabanero CR instances in the kabanero namespace, run the following command:

    ```
    oc get kabaneros -n kabanero
    ```

    To obtain the configuration for a specific CR instance, run the following command, substituting `<name>` for the instance you are targeting:

    ```
    oc get kabanero <name> -n kabanero -o yaml > kabanero.yaml
    ```

    This example assumes that you kept the default `<name>`, which is `kabanero`.

2. Edit the `kabanero.yaml` file that you generated in the last step.

    Update the following section, which shows the configuration for stack repositories:

    ```
    stacks:
      repositories:
      - name:
        https:
          url:
          skipCertVerification: [true|false]
      - name:
        https:
          url:
          skipCertVerification: [true|false]
    ```

    Where:

    - `repositories` lists the repositories to search for stacks
    - `name` is the name of your repository
    - `url` contains the URL string for the `index.yaml` file
    - `skipCertVerification` determines whether to verify the certificate before activating (default is `false`)

    To change the desired state for a repository after the instance is deployed, you must edit each resource manually.

    The following configuration can be used for the repository you created earlier:

    ```
    stacks:
      repositories:
      - name: my-org-repository
        https:
          url: https://github.com/myorg/my-org-repository/releases/latest/download/my-org-repository-index.yaml
    ```

3. Save the file.

4. Apply the changes to your Kabanero CR instance with the following command:

    ```
    oc apply -f kabanero.yaml -n kabanero
    ```

Applications that have been developed using your stack can now be deployed to your Kubernetes cluster.

## Transport layer security (TLS) verification for image registry access in pipelines

when accessing image registries to pull and push images, pipelines enable the configuration creation of the cluster resource, [image.config.openshift.io/cluster](https://docs.openshift.com/container-platform/4.2/openshift_images/image-configuration.html#images-configuration-file_image-configuration).  Scenarios are presented of image registries that can be used and the setup steps required.

### Enable TLS verification for image registry access:

#### Private image registries:
 
If you use a private image registry and your registry uses certificates that are signed by trusted CA authorities, no further configuration is needed to enable TLS verification. Review the default truststore on the nodes of your cluster to ensure that you have the CA of your certificate in the list. With a self-signed certificates or a certificate that is signed by a CA, you must ensure that either certificate is listed in the default truststore. Steps are presented to add the CA to the trusted list so that when you run the pipelines, these CA certificates in the list are used.

 - Ensure that you have access to the ca.crt files for your private registries.

 - Use the instructions for [adding certificate authorities to the cluster](https://docs.openshift.com/container-platform/4.3/builds/setting-up-trusted-ca.html#configmap-adding-ca_setting-up-trusted-ca) to create a configmap with the `key` as your private registry `hostname` and value as the content of your private registry `ca.crt` file. This configmap must be present in the `openshift-config` namespace.

#### Internal OpenShift image registry external route

When you use the internal OpenShift image registry that is provided in your OCP cluster and want to access it using the external route,

- Run an `oc patch` command to enable the default external route when you do not have the external route setup for your internal image registry on your cluster. 

```
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'
```

- Run the `oc get` command to verify that you have the external route and check `externalRegistryHostnames` in the output.

```
oc get image.config.openshift.io/cluster -o yaml 
```
Sample output
```
# oc get image.config.openshift.io/cluster -o yaml 
apiVersion: config.openshift.io/v1
kind: Image
metadata:
  annotations:
    release.openshift.io/create-only: "true"
  creationTimestamp: "2020-03-24T16:34:58Z"
  generation: 11
  name: cluster
  resourceVersion: "8570660"
  selfLink: /apis/config.openshift.io/v1/images/cluster
  uid: 7ba0dae1-c579-4adf-828d-44b0c3652bae
spec: {}
status:
  externalRegistryHostnames:
  - default-route-openshift-image-registry.apps.incult.os.fyre.ibm.com
  internalRegistryHostname: image-registry.openshift-image-registry.svc:5000
```

- Once you have the external route and the `ca.crt` for the internal image registry external route, use the steps in section, `Private image registries`.  @aadeshpa how do you get the ca.crt?  can we add a pointer here?

### Disable TLS verification for image registry access:

If your private or internal registry does not have a valid TLS certificate or supports only HTTP connections, you must configure your cluster differently by disabling TLS verification first to allow pulling images from this registry. Use the `oc patch` command with your registry to accomplish this. If you use the `oc path` command for multiple image registries, the registry URL entries must be separated by commas.

```
oc patch --type=merge --patch='{
 "spec": {
   "registrySources": {
     "insecureRegistries": [
       "<registry>", "abc.com" , "pqr.com"
     ]
   }
 }
}' image.config.openshift.io/cluster

```

**NOTE:** When accessing the internal registry using the internal route, the pipelines disable TLS verification by default.
