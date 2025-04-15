# Koha Plugin Auto Release Template

This template provides an automated release process for Koha plugins, based on the Bywater Solutions auto-release workflow.

## Features

- Automated version management
- GitHub Actions workflow for testing and releasing
- Automated KPZ file creation
- Support for multiple Koha versions (main, stable, oldstable)
- Automated GitHub releases

## Prerequisites

- Node.js and npm (for local development and version management)

## Setup

1. Clone this repository
2. Update the plugin metadata in your .pm file:
   ```perl
   our $metadata = {
       name            => 'Your Plugin Name',
       author          => 'Your Name',
       description     => 'Description of your plugin',
       date_authored   => 'YYYY-MM-DD',
       date_updated    => 'YYYY-MM-DD',
       minimum_version => $MINIMUM_VERSION,
       maximum_version => undef,
       version         => $VERSION,
   };
   ```
3. Update the `package.json` file with your plugin's information:
   ```json
   {
       "plugin": {
           "module": "Koha::Plugin::Com::YourOrg::YourPlugin",
           "pm_path": "Koha/Plugin/Com/YourOrg/YourPlugin.pm"
       },
       "version": "1.0.0",
       "previous_version": "0.0.0"
   }
   ```
4. Install dependencies:
   ```bash
   npm install
   ```

## Usage

### Version Management

The template includes a version management system that automatically increments versions. To update the version:

```bash
# For a patch version bump (1.0.0 -> 1.0.1)
npm run version:patch

# For a minor version bump (1.0.0 -> 1.1.0)
npm run version:minor

# For a major version bump (1.0.0 -> 2.0.0)
npm run version:major
```

This will:
1. Increment the version number
2. Update both version and previous_version in package.json
3. Update the version in your plugin's .pm file

### Creating Releases

To create a release:

```bash
# For a patch release
npm run release:patch

# For a minor release
npm run release:minor

# For a major release
npm run release:major
```

This will:
1. Bump the version
2. Create a git commit
3. Create a git tag
4. Push to GitHub

The GitHub Actions workflow will then:
1. Run tests against multiple Koha versions
2. Create a KPZ file for your plugin
3. Create a GitHub release with the KPZ file and CHANGELOG.md

### Testing

The workflow runs tests against three Koha versions:
- main (development)
- stable (current stable release)
- oldstable (previous stable release)

Tests are run using koha-testing-docker in the GitHub Actions environment.

## Customization

You can customize the workflow by:

1. Modifying the test matrix in `.github/workflows/main.yml`
2. Adding additional test steps
3. Customizing the release process
4. Modifying the version increment logic in `increment_version.js`

## License

This template is licensed under the GPL-3.0 license.