# Koha Suppression Indexer Plugin

This plugin creates an indexed database table for MARC 942$n suppression values, enabling faster report queries without requiring complex ExtractValue operations.

## Features

- **Indexed Suppression Table**: Creates `plugin_suppression_index` with biblionumber and suppression_value columns
- **Real-time Updates**: Uses `after_biblio_action` hook to update index immediately when biblios change
- **Nightly Sync**: Bulk updates all records via `cronjob_nightly` to catch any missed changes
- **Fast Report Queries**: Join to the indexed table instead of using ExtractValue in WHERE clauses
- **Automated Releases**: GitHub Actions workflow for testing and releasing
- **Version Management**: Automated versioning and KPZ file creation
- **Multi-Version Support**: Tested against Koha main, stable, and oldstable branches

## Prerequisites

- Node.js and npm (for local development and version management)

## Installation

### In Koha

1. Download the latest `.kpz` file from the [Releases](../../releases) page
2. In Koha, go to **Administration** > **Manage plugins**
3. Click **Upload plugin** and select the downloaded `.kpz` file
4. Enable the plugin

The plugin will automatically:
- Create the `plugin_suppression_index` table
- Update the index in real-time when biblios are created, modified, or deleted
- Perform bulk sync during nightly cronjob runs

### For Development

1. Clone this repository
2. Install Node.js dependencies:
   ```bash
   npm install
   ```

## Using the Plugin

### In SQL Reports

After the nightly cronjob has run, you can join to the indexed table in your reports:

```sql
SELECT
    b.biblionumber,
    b.title,
    b.author,
    s.suppression_value
FROM biblio b
LEFT JOIN plugin_suppression_index s USING (biblionumber)
WHERE s.suppression_value = 'your_value'
```

This is much faster than:
```sql
-- Slow: ExtractValue in WHERE clause
WHERE ExtractValue(metadata, '//datafield[@tag="942"]/subfield[@code="n"]') = 'your_value'
```

### Index Updates

The index updates automatically in two ways:

1. **Real-time**: Immediately when biblios are created, modified, or deleted (via `after_biblio_action` hook)
2. **Nightly**: Bulk sync of all records via cronjob (catches any missed updates)

To manually trigger a full sync, run the plugin's cronjob method from the Koha plugin interface.

## Development

### Version Management

To update the plugin version:

```bash
# For a patch version bump (1.0.0 -> 1.0.1)
npm run version:patch

# For a minor version bump (1.0.0 -> 1.1.0)
npm run version:minor

# For a major version bump (1.0.0 -> 2.0.0)
npm run version:major
```

This will:
1. Increment the version number in `package.json`
2. Update the version in `Koha/Plugin/Com/OpenFifth/Suppression.pm`
3. Update the `date_updated` field

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
1. Run tests against Koha main, stable, and oldstable
2. Create a KPZ file
3. Create a GitHub release with the KPZ file

### Testing

The workflow runs tests against three Koha versions:
- main (development)
- stable (current stable release)
- oldstable (previous stable release)

Tests are run using koha-testing-docker in the GitHub Actions environment.

## Database Schema

The plugin creates the following table:

```sql
CREATE TABLE plugin_suppression_index (
    biblionumber INT(11) NOT NULL,
    suppression_value VARCHAR(255) DEFAULT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (biblionumber),
    INDEX idx_suppression_value (suppression_value)
)
```

## Customization

To index a different MARC field, modify the SQL query in **both** the `after_biblio_action()` and `cronjob_nightly()` methods in `Koha/Plugin/Com/OpenFifth/Suppression.pm`:

```perl
ExtractValue(metadata, '//datafield[@tag="XXX"]/subfield[@code="Y"]')
```

**Note:** Both methods must use the same extraction logic to ensure consistency between real-time and bulk updates.

## License

GPL-3.0