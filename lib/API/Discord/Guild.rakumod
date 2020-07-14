use Object::Delayed;
use API::Discord::Object;
use API::Discord::Endpoints;
use API::Discord::Permissions;

unit class API::Discord::Guild does API::Discord::Object is export;

class ButReal does API::Discord::DataObject {
    has $.id;
    has $.name;
    has $.icon;
    has $.splash;
    has $.is-owner;
    has $.owner-id;
    has $.permissions;
    has $.region;
    has $.afk-channel-id;
    has $.afk-channel-timeout;
    has $.is-embeddable;
    has $.embed-channel-id;
    has $.verification-level;
    has $.default-notification-level;
    has $.content-filter-level;
    has $.mfa-level-required;
    has $.application-id;
    has $.is-widget-enabled;
    has $.widget-channel-id;
    has $.system-channel-id;
    has DateTime $.joined-at;
    has $.is-large;
    has $.is-unavailable;
    has $.member-count;

    method to-json {
        my %self = self.Capture.hash;
        my %json = %self<id name icon splash>:kv;

        %json<owner> = %self<is-owner>;

        return %json;
    }

    method from-json (%json) {
        # TODO I guess
        my %constructor = %json<id name icon splash>:kv;
        %constructor<is-owner> = %json<owner>;

        return self.new(|%constructor);
    }
}

class Member { ... };

enum MessageNotificationLevel (
    <notification-all-messages notification-only-mentions>
);

enum ContentFilterLevel (
    <filter-disabled filter-members-without-roles filter-all-members>
);

enum MFALevel (
    <mfa-none mfa-elevated>
);

enum VerificationLevel (
    <verification-none verification-low verification-medium verification-high verification-very-high>
);

has $.real handles <
    name
    icon
    splash
    is-owner
    owner-id
    permissions
    region
    afk-channel-id
    afk-channel-timeout
    is-embeddable
    embed-channel-id
    verification-level
    default-notification-level
    content-filter-level
    mfa-level-required
    application-id
    is-widget-enabled
    widget-channel-id
    system-channel-id
    joined-at
    is-large
    is-unavailable
    member-count

    create
    read
    update
    delete
> = slack { await API::Discord::Guild::ButReal.read({:$!id, :$!api}, $!api.rest) };

multi method reify (::?CLASS:U: $data) {
    ButReal.from-json($data);
}

multi method reify (::?CLASS:D: $data) {
    my $r = ButReal.from-json($data);
    $!real = $r;
}

has @.roles;
has @.emojis;
has @.features;
has @.voice-states;
has @.members;
has @.channels;
has @.presences;

method assign-role($user, *@role-ids) {
    start {
        my $member = self.get-member($user);

        $member<roles>.append: @role-ids;

        await self.update-member($user, { roles => $member<roles> });
    }

}

method unassign-role($user, *@role-ids) {
    start {
        my $member = self.get-member($user);

        $member<roles> = $member<roles>.grep: @role-ids !~~ *;
        say $member;

        await self.update-member($user, { roles => $member<roles> });
    }
}

multi method get-member(API::Discord::Object $user) returns Member {
    # The type constraint is to help selecting the multi candidate, not to
    # constrain it to User objects.
    samewith($user.real-id);
}

multi method get-member(Str() $user-id) returns Member {
    my $e = endpoint-for( self, 'get-member', :$user-id );
    my $member = $.api.rest.get($e).result.body.result;
    $member<guild> = self;
    $.api.inflate-member($member);
}

multi method update-member(API::Discord::Object $user, %new-data) returns Promise {
    samewith($user.id, %new-data);
}

multi method update-member(Int $user-id, %new-data) returns Promise {
    my $e = endpoint-for( self, 'get-member', :$user-id );
    $.api.rest.patch($e, body => %new-data)
}

multi method remove-member(API::Discord::Object $user) returns Promise {
    samewith($user.id);
}

multi method remove-member(Int $user-id) returns Promise {
    my $e = endpoint-for( self, 'remove-member', :$user-id );
    return $.api.rest.delete($e);
}

class Member does API::Discord::DataObject {
    has $.guild;
    has $.user;
    has $.nick;
    has Bool $.is-owner;
    has @.roles;
    has DateTime $.joined-at;
    has DateTime $.premium-since;
    has Bool $.is-deaf;
    has Bool $.is-mute;

    method combined-permissions returns Int {
        @.roles.map(*<permissions>).reduce(&[+|]);
    }

    method has-all-permissions(PERMISSION @permissions) returns Bool {
        return True if $.is-owner;
        API::Discord::Permissions::has-all-permissions(self.combined-permissions, @permissions);
    }

    method has-any-permission(PERMISSION @permissions) returns Bool {
        return True if $.is-owner;
        API::Discord::Permissions::has-any-permission(self.combined-permissions, @permissions);
    }

    method to-json() returns Hash {
    }

    method from-json(%json) {
        my %constructor = %json<nick roles guild>:kv;
        my $api = %constructor<api> = %json<_api>;

        %constructor<is-deaf is-mute> = %json<deaf mute>;

        %constructor<user> = $api.inflate-user(%json<user>);
        %constructor<owner> = %constructor<guild>.owner-id == %constructor<user>.id;

        %constructor<joined-at> = DateTime.new(%json<joined_at>);
        %constructor<premium-since> = DateTime.new($_) with %json<premium_since>;

        return self.new(|%constructor);
    }
}
=begin pod

=head1 NAME

API::Discord::Guild - Colloquially known as a server

=head1 DESCRIPTION

Defines a guild, or server, slightly adapting the JSON object defined in the
documentation at L<https://discordapp.com/developers/docs/resources/guild>.

Guilds are usually created by the websocket layer, as a result of the bot user
being added to the guild. However, the Discord documentation does allow for
guilds to be fetched or created via the API in some circumstances. Knowing
whether or not you can do this is up to the user; you can always try.

=end pod
=begin pod
=head2 JSON fields

See L<API::Discord::Object> for JSON fields discussion

    < id name icon splash is-owner owner-id permissions region afk-channel-id
    afk-channel-timeout is-embeddable embed-channel-id verification-level
    default-notification-level content-filter-level mfa-level-required
    application-id is-widget-enabled widget-channel-id system-channel-id joined-at
    is-large is-unavailable member-count >

=end pod
=begin pod
=head2 Object properties

See L<API::Discord::Object> for Object properties discussion

    < roles emojis features voice-states members channels presences >

=end pod
