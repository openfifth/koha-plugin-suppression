# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the Suppression Indexer plugin for Koha, which creates a searchable index of MARC 942$n suppression values to improve report performance. The plugin uses automated version management and release workflows based on the Bywater Solutions auto-release workflow and uses GitHub Actions for CI/CD.

## Architecture

### Core Components

**Plugin Module** (`Koha/Plugin/Com/OpenFifth/Suppression.pm`)
- Main plugin class inheriting from `Koha::Plugins::Base`
- Contains metadata including version, author, description, and Koha compatibility
- Implements lifecycle methods: `install()`, `upgrade()`, `uninstall()`
- Implements `cronjob_nightly()` to populate the suppression index
- Version defined in `$VERSION` variable (format: x.y.z)
- Minimum Koha version defined in `$MINIMUM_VERSION` (format: "22.05.00.000")

**Database Schema** (`plugin_suppression_index` table)
- `biblionumber` (INT, PRIMARY KEY) - References biblio table
- `suppression_value` (VARCHAR(255), INDEXED) - The MARC 942$n value
- `last_updated` (TIMESTAMP) - Last time the record was updated
- Created during `install()`, dropped during `uninstall()`

**Real-time Updates**
- Method: `after_biblio_action()` - Hook triggered after biblio create/modify/delete operations
- Parameters: `action` ('create', 'modify', 'delete'), `biblio_id` (biblionumber)
- Updates single record immediately when biblios change
- Deletes index entry when biblio is deleted
- Available since Koha 19.11 (Bug 22709)

**Nightly Cronjob**
- Method: `cronjob_nightly()` - Called automatically by Koha's cronjob system
- Bulk updates all biblios for initial population and catching missed records
- Executes SQL using `ExtractValue()` to extract MARC 942$n from biblio_metadata
- Uses `REPLACE INTO` to handle both new records and updates
- Only processes MARC21 records from biblio_metadata table

**Version Management** (`increment_version.js`)
- Node.js script that manages semantic versioning
- Updates both `package.json` and the plugin .pm file
- Synchronizes version and `date_updated` metadata field
- Preserves Perl whitespace formatting when updating version declarations

**Configuration** (`package.json`)
- Tracks current version and previous version
- Defines plugin module path via `plugin.module` and `plugin.pm_path`
- Contains npm scripts for version bumping and releasing

### Version Synchronization System

The codebase maintains version consistency across two files:
1. `package.json` - Tracks `version` and `previous_version`
2. Plugin .pm file - Contains `$VERSION` variable and `date_updated` in metadata

The `increment_version.js` script updates both files atomically to prevent version drift.

## Common Commands

### Version Management

```bash
# Bump version (updates package.json and .pm file only, no commit)
npm run version:patch  # 1.0.0 -> 1.0.1
npm run version:minor  # 1.0.0 -> 1.1.0
npm run version:major  # 1.0.0 -> 2.0.0
```

### Release Management

```bash
# Create release (bump version, commit, tag, push)
npm run release:patch  # Creates v1.0.x release
npm run release:minor  # Creates v1.x.0 release
npm run release:major  # Creates vx.0.0 release
```

Release scripts perform:
1. Run `increment_version.js` to bump version
2. Stage only version-related files (`package.json` and plugin .pm)
3. Create commit with message "chore: bump version"
4. Create annotated git tag (e.g., `v1.0.1`)
5. Push to `main` branch with `--follow-tags`

### Testing

```bash
# Run tests locally (requires koha-testing-docker setup)
prove t/

# Run specific test
prove t/00-load.t
```

The test suite requires these Perl dependencies:
- `JSON::MaybeXS`
- `Path::Tiny`
- `Test::Exception`

Tests read `package.json` to validate plugin version consistency.

## CI/CD Workflow

### GitHub Actions (`.github/workflows/main.yml`)

**Triggers:**
- Push to `master` branch (note: workflow uses `master`, but repo default is `main`)
- Version tags matching `v*.*.*`
- Weekly cron job (Mondays at 6 AM UTC)

**Test Matrix:**
Tests run against two Koha versions:
- `main` - Development branch
- `stable` - Current stable release

**Test Process:**
1. Checkout plugin code
2. Clone appropriate Koha version branch
3. Setup koha-testing-docker environment
4. Install test dependencies via `cpanm`
5. Copy plugin to `/var/lib/koha/kohadev/plugins`
6. Run tests with `prove`

**Release Process (tag pushes only):**
1. Run unit tests on all Koha versions
2. Build KPZ (Koha Plugin Package) file
3. Create GitHub release with:
   - KPZ artifact
   - `CHANGELOG.md` (must exist in repo)
   - Auto-generated release notes

### Key Workflow Details

- Tests install dependencies: `JSON::MaybeXS`, `Path::Tiny`, `Test::Exception`
- 180-second sleep after container startup to ensure Koha is ready
- Environment variable `KOHA_PLUGIN_DIR` points to plugin location
- KPZ minimum version set to stable major.minor version
- Elasticsearch and Selenium disabled to reduce memory usage in CI

## Development Notes

### When modifying version management:

- The `increment_version.js` script uses regex to update version strings
- It preserves specific whitespace formatting for perltidy compatibility
- Version regex: `/our \$VERSION\s+=\s+["']\d+\.\d+\.\d+["'];/`
- Date regex: `/date_updated\s*=>\s*["'][^"']+["']/`

### When adding plugin functionality:

- Add methods to the main plugin class
- Plugin has access to `C4::Context`, `Koha::DateUtils`, and `Koha::Biblios`
- Use `$self` to access plugin metadata and methods from base class
- Implement database operations in `install()`, upgrades in `upgrade()`
- Database schema changes should be handled in `upgrade()` method
- The `cronjob_nightly()` method runs automatically via Koha's cronjob system

### Plugin-Specific Notes:

**Suppression Index Usage:**
- The `plugin_suppression_index` table can be joined in SQL reports
- Example report query:
  ```sql
  SELECT b.biblionumber, b.title, s.suppression_value
  FROM biblio b
  LEFT JOIN plugin_suppression_index s USING (biblionumber)
  WHERE s.suppression_value = 'desired_value'
  ```

**Real-time vs Nightly Updates:**
- **Real-time**: The `after_biblio_action` hook updates index immediately when biblios change
- **Nightly**: The `cronjob_nightly` performs bulk updates of all records
- Both methods serve different purposes and work together
- Real-time ensures current data; nightly catches any missed updates

**MARC Field Extraction:**
- Currently hardcoded to extract MARC21 942$n
- Uses MySQL's `ExtractValue()` function on XML metadata
- To support other MARC formats, modify the SQL in both `after_biblio_action()` and `cronjob_nightly()`

**Performance Considerations:**
- Real-time updates process single records with minimal performance impact
- The nightly cronjob processes all biblio records for bulk sync
- For large databases (>1M records), consider batching in `cronjob_nightly()`
- The indexed `suppression_value` field enables fast WHERE clause filtering

**Available Hooks:**
- `after_biblio_action` - Real-time updates when biblios change (implemented)
- `after_item_action` - Could be added for item-level changes if needed
- `before_biblio_action` - Pre-modification hook (Koha 24.05+)

### When writing tests:

- Place test files in `t/` directory
- Use `Test::More` and `Test::Exception` for test structure
- Access plugin directory via `$ENV{KOHA_PLUGIN_DIR}`
- Read `package.json` to get expected version and module name
- Tests must work both locally and in koha-testing-docker

## Required Files for Releases

- `CHANGELOG.md` - Referenced by GitHub Actions but not tracked in template
- `package.json` - Must contain valid `plugin.module` and `plugin.pm_path`
- Plugin .pm file at path specified in `package.json`
