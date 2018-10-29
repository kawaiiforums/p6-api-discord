use API::Discord::Object;
use API::Discord::Endpoints;

unit class API::Discord::User does API::Discord::Object is export;

=begin pod

=head1 NAME

API::Discord::User - Represents Discord user

=head1 DESCRIPTION

Represents a Discord user, usually sent to use via the websocket. See
L<https://discordapp.com/developers/docs/resources/user>.

Users cannot be created or deleted.

See also L<API::Discord::Object>.

=head1 PROMISES

=head2 guilds

Resolves to a list of L<API::Discord::Guild> objects

=head2 dms

Resolves to a list of L<API::Discord::Channel> objects (direct messages)

=end pod

has Promise $!dms-promise;
has Promise $!guilds-promise;

has $.id;
has $.username;
has $.discriminator;
has $.avatar;        # The actual image
has $.avatar-hash;   # The URL bit for the CDN
has $.is-bot;
has $.is-mfa-enabled;
has $.is-verified;
has $.email;
has $.locale;

method guilds($force?) returns Promise {
    if $force or not $!guilds-promise {
        $!guilds-promise = start {
            my @guilds;
            my $e = endpoint-for( self, 'get-guilds' ) ;
            my $p = await $.api.rest.get($e);
            @guilds = (await $p.body).map( { $!api.inflate-guild($_) } );
            @guilds;
        }
    }

    $!guilds-promise
}

method dms($force?) returns Promise {
    if $force or not $!dms-promise {
        $!dms-promise = start {
            my @dms;
            my $e = endpoint-for( self, 'get-dms' ) ;
            my $p = await $.api.rest.get($e);
            @dms = (await $p.body).map: $!api.inflate-channel(*);
            @dms;
        }
    }

    $!guilds-promise
}

#| to-json might not be necessary
method to-json {}
method from-json ($json) {
    my %constructor = $json<id username discriminator email locale>:kv;

    %constructor<avatar-hash is-bot is-mfa-enabled is-verified>
        = $json<avatar bot mfa_enabled verified>;

    %constructor<api> = $json<_api>;
    return self.new(|%constructor);
}
