unit class API::Discord::Message is export;

use API::Discord::Object;
use URI::Encode;
use Object::Delayed;

class ButReal does API::Discord::Object {
    has $.id;
    has $.channel-id;

    has $.author-id;
    has $.nonce;
    has $.content;
    has $.is-tts;
    has $.mentions-everyone;
    has $.is-pinned;
    has $.webhook-id;
    has @.mentions-role-ids;
    has @.mentions;
    has $.type;

    # Coercions here are not yet implemented
    has DateTime $.timestamp;
    has DateTime $.edited;

    submethod new(*%args) {
        %args<timestamp> = DateTime.new(%args<timestamp>);
        %args<edited> = DateTime.new($_) with %args<edited>;

        self.bless(|%args);
    }

    method from-json (%json) returns ::?CLASS {
        my $api = %json<_api>;
        # These keys we can lift straight out
        my %constructor = %json<id nonce content type>:kv;

        # These keys we sanitized for nice Perl6 people
        %constructor<channel-id is-tts mentions-everyone is-pinned webhook-id mentions-role-ids embeds>
            = %json<channel_id tts mention_everyone pinned webhook_id mention_roles embeds>;

        # Just store the ID. If we want the real author we can fetch it later. I
        # can't be bothered stitching this sort of thing together just to save a
        # few bytes.
        if ! %json<webhook_id> {
            %constructor<author-id> = $api.get-user(%json<author><id>);
        }
        %constructor<mentions> = %json<mentions>.map( {$api.get-user($_)} ).Array;

    #    %constructor<attachments> = $json<attachments>.map: self.create-attachment($_);
    #    %constructor<reactions> = $json<reactions>.map: self.create-reaction($_);

        %constructor<api> = $api;
        return self.new(|%constructor.Map);
    }

    #| Deflates the object back to JSON to send to Discord
    method to-json returns Hash {
        my %self := self.Capture.hash;
        my %json = %self<id nonce type timestamp>:kv;
        %json<edited_timestamp> = $_ with %self<edited>;

        # Can't send blank content but we might have embed with no content
        %json<content> = $_ with %self<content>;

        %json<channel_id tts mention_everyone pinned webhook_id mention_roles embed>
            = %self<channel-id is-tts mentions-everyone is-pinned webhook-id mentions-role-ids embed>;

        # I kinda don't want to update this I think
        # $.author andthen %json<author> = .to-json;

        for <mentions attachments reactions> -> $prop {
            %self{$prop} andthen %json{$prop} = [map *.to-json, $_.values]
        }

        return %json;
    }
}

class Activity {
    enum Type (
        0 => 'join',
        2 => 'spectate',
        3 => 'listen',
        5 => 'join-request',
    );

    has Type $.type;
    has $.party-id;
}

class Reaction does API::Discord::Object {
    # This class is special because a) only Message uses it and b) it doesn't
    # use the default HTTP logic when sending.
    has $.emoji;
    has $.count;
    has $.i-reacted;
    has $.user;

    has $.message;

    method self-send(Str $endpoint, $resty) returns Promise {
        $resty.put: "$endpoint", body => {};
    }
    method from-json($json) {
        # We added message because only the Message class calls this
        self.new(|$json);
    }

    method to-json { {} }
}

enum Type (
    <default recipient-add>
);

=head1 PROPERTIES

# Both id and channel id are required to fetch a message.
has $.id;
has $.channel-id;
has $.api;
has $.real handles <
    author-id
    nonce
    content
    is-tts
    mentions-everyone
    is-pinned
    webhook-id
    mentions-role-ids
    mentions
    type
    timestamp
    edited

    create
    read
    update
    delete
> = slack { await API::Discord::Message::ButReal.read({:$!channel-id, :$!id, :$!api}, $!api.rest) };

multi method reify (::?CLASS:U: $data, $api) {
    ButReal.from-json(%(|$data, _api => $api));
}

multi method reify (::?CLASS:D: $data) {
    my $r = ButReal.from-json(%(|$data, _api => $.api));
    $!real = $r;
}

has $.author;
has @.mentions-roles; # will lazy { ... }
has @.attachments;
# GET a message and receive embeds plural. SEND a message and you can only send
# one. I do not know at this point how you can create multiple embeds.
has @.embeds;
has $.embed;
# TODO: perhaps this should be emoji => count and we don't need the Reaction class.
# (We can use Emoji objects as the keys if we want)
has @.reactions;

# TODO
#has API::Discord::Activity $.activity;
#has API::Discord::Application $.application;

method addressed returns Bool {
    self.mentions.first({ $.api.user.real-id == $_.real-id }).Bool
}

#| Asks the API for the Channel object.
method channel {
    $.api.get-channel(self.channel-id);
}

method add-reaction(Str $e is copy) {
    $e = uri_encode_component($e) unless $e ~~ /\:/;
    Reaction.new(:emoji($e), :user('@me'), :message(self)).create($.api.rest);
}

#| Pins this message to its channel.
method pin returns Promise {
    self.channel(:now).pin(self)
}

#| Inflates the Message object from the JSON we get from Discord

=begin pod

=head1 NAME

API::Discord::Message - Represents Discord message

=head1 DESCRIPTION

Represents a Discord message in a slightly tidier way than raw JSON. See
L<https://discordapp.com/developers/docs/resources/channel#message-object>,
unless it moves.

Messages are usually created when the websocket sends us one. Each is associated
with a Channel object.

=head1 TYPES

=head2 JSON fields

See L<API::Discord::Object> for JSON fields discussion

    < id channel-id nonce content is-tts mentions-everyone is-pinned webhook-id
    mentions-role-ids type timestamp edited >

=head2 Object accessors

See L<API::Discord::Object> for Object properties discussion

    < channel author mentions mentions-roles attachments embeds reactions >

=head1 METHODS

=head2 new

A Message can be constructed by providing any combination of the JSON accessors.

If any of the object accessors are set, the corresponding ID(s) in the JSON set
will be set, even if you passed that in too.

This ensures that they will be consistent, at least until you break it on
purpose.

=head2 addressed
Does the API user appear in the mentions array?

=head2 add-reaction
Provide a string containg the emoji to use. This is either a unicode emoji, or a
fully-specified guild-specific emoji of the form C<$name:$id>, e.g.
C<flask:502112742656835604>
=end pod
