package Koha::Plugin::Com::OpenFifth::Suppression;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use Koha::DateUtils;
use Koha::Biblios;

our $VERSION         = '0.0.0';
our $MINIMUM_VERSION = "22.05.00.000";

our $metadata = {
    name            => 'Suppression Indexer',
    author          => 'OpenFifth',
    description     => 'Indexes MARC 942$n suppression values for faster report queries',
    date_authored   => '2025-10-21',
    date_updated    => '2025-10-21',
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

sub install {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    # Create the suppression index table
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS plugin_suppression_index (
            biblionumber INT(11) NOT NULL,
            suppression_value VARCHAR(255) DEFAULT NULL,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (biblionumber),
            INDEX idx_suppression_value (suppression_value)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    });

    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;

    # Future upgrades can be handled here
    return 1;
}

sub uninstall {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    # Drop the suppression index table
    $dbh->do(q{
        DROP TABLE IF EXISTS plugin_suppression_index
    });

    return 1;
}

sub after_biblio_action {
    my ( $self, $params ) = @_;

    my $action      = $params->{action};      # 'create', 'modify', or 'delete'
    my $biblionumber = $params->{biblio_id};

    return unless $biblionumber;

    my $dbh = C4::Context->dbh;

    if ( $action eq 'delete' ) {
        # Remove from index when biblio is deleted
        $dbh->do(
            q{DELETE FROM plugin_suppression_index WHERE biblionumber = ?},
            undef,
            $biblionumber
        );
    } else {
        # Update index for create/modify actions
        # Use REPLACE to handle both inserts and updates
        my $sql = q{
            REPLACE INTO plugin_suppression_index (biblionumber, suppression_value, last_updated)
            SELECT
                biblio_metadata.biblionumber,
                ExtractValue(metadata, '//datafield[@tag="942"]/subfield[@code="n"]') AS suppression_value,
                NOW()
            FROM biblio_metadata
            WHERE biblio_metadata.biblionumber = ?
            AND biblio_metadata.format = 'marcxml'
            AND biblio_metadata.schema = 'MARC21'
        };

        $dbh->do( $sql, undef, $biblionumber );
    }

    return 1;
}

sub cronjob_nightly {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    # Bulk update for all biblios - useful for initial population
    # and catching any records that may have been missed
    # Use REPLACE to handle both inserts and updates
    # ExtractValue extracts the MARC 942$n value from the metadata XML
    my $sql = q{
        REPLACE INTO plugin_suppression_index (biblionumber, suppression_value, last_updated)
        SELECT
            biblio_metadata.biblionumber,
            ExtractValue(metadata, '//datafield[@tag="942"]/subfield[@code="n"]') AS suppression_value,
            NOW()
        FROM biblio_metadata
        WHERE biblio_metadata.format = 'marcxml'
        AND biblio_metadata.schema = 'MARC21'
    };

    $dbh->do($sql);

    return 1;
}

1;
