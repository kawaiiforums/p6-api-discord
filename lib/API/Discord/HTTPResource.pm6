use API::Discord::Endpoints;

unit package API::Discord;

=begin pod

=head1 NAME

API::Discord::JSONy - Role for objects that can be serialised to JSON

API::Discord::RESTy - Role for objects that can be sent/received over REST

API::Discord::HTTPResource - Role for objects that can be CRUD'd

API::Discord::HTTPMessage - Class representing the various JSON things we get sent

=head1 DESCRIPTION

This file defines the three roles and one class listed above. They are all
related to one another but not necessarily all required at once.

I bunged all the HTTP stuff in one place because it didn't seem necessary to do
otherwise... the wisdom of this decision, time will tell.

=head1 API::Discord::JSONy

This role defines the methods C<from-json> and C<to-json> that must be
implemented by the consuming class. Anything using this role can be sent to or
produced by RESTy.

=end pod


role JSONy is export {
    #| Builds the object from a hash. The hash is made from the JSON, courtesy
    #| of Cro.
    method from-json (::?CLASS:U: $json) { ...  }

    #| Turns the object into a hash. from-json(to-json($object)) should return
    #| the same object (or at least an equivalent copy).
    method to-json returns Hash { ... }
}

=begin pod

=head1 API::Discord::RESTy[$base-url]

This role defines C<send>, C<fetch>, and C<remove>, and is parameterised with a
base URL. It abstracts over the top of an HTTP client, so requires C<get>,
C<post>, C<put>, and C<delete> methods.

It is intended to be applied to L<Cro::HTTP::Client>, so the aforementioned
methods should match those.

=end pod

role RESTy[$base-url] is export {
    has $.base-url = $base-url;

    multi method get ($uri, %args) {
        callwith("$.base-url$uri", %args);
    }
    multi method get ($uri, *%args) {
        callwith("$.base-url$uri", |%args);
    }
    multi method post ($uri, %args) {
        callwith("$.base-url$uri", %args);
    }
    multi method post ($uri, *%args) {
        callwith("$.base-url$uri", |%args);
    }
    multi method patch ($uri, %args) {
        callwith("$.base-url$uri", %args);
    }
    multi method patch ($uri, *%args) {
        callwith("$.base-url$uri", |%args);
    }
    multi method put ($uri, %args) {
        callwith("$.base-url$uri", %args);
    }
    multi method put ($uri, *%args) {
        callwith("$.base-url$uri", |%args);
    }
    multi method delete ($uri, %args) {
        callwith("$.base-url$uri", %args);
    }
    multi method delete ($uri, *%args) {
        callwith("$.base-url$uri", |%args);
    }

    #| Sends a JSONy object to the given endpoint. Updates if the object has an
    #| ID; creates if it does not.
    method send(Str $endpoint, JSONy:D $object) returns Promise {
        if $object.can('self-send') {
            return $object.self-send($endpoint, self)
        }
        # TODO: does anything generate data such that we need to re-fetch after
        # creation?
        use Data::Dump;
        my $body = $object.to-json;
        if $object.can('id') and $object.id {
            say "PATCH $endpoint " ~ Dump $body if %*ENV<API_DISCORD_DEBUG>;
            self.patch: $endpoint, :$body;
        }
        else {
            say "POST $endpoint " ~ Dump $body if %*ENV<API_DISCORD_DEBUG>;
            self.post: $endpoint, :$body;
        }
    }

    #| Sends a PUT but no data required. Useful to avoid creating whole classes
    #| just so they can self-send
    method touch(Str $endpoint) returns Promise {
        self.put: $endpoint, body => {};
    }

    #| Creates a JSONy object, given a full URL and the class.
    method fetch(Str $endpoint, JSONy:U $class, %data) returns Promise {
        start {
            my $b = await (await self.get($endpoint, %data)).body;
            $class.from-json($b);
        }
    }

    #| Deletes the thing with DELETE
    method remove(Str $endpoint) returns Promise {
        self.delete: $endpoint;
    }
}

=begin pod

=head1 API::Discord::HTTPResource

Represents an object that can be discovered via some HTTP mechanism. The
consuming class is expected to have a hash called C<%.ENDPOINTS>, the purpose of
which is to provide a set of URL path templates that can be filled in by the
object being dealt with.

Endpoint handling is not yet fully implemented.

A gap in this process is that it does mean that in order to fetch an existing
object by ID, it is necessary to create an empty object containing that ID, and
then replace it with the response from C<read>, which will be a new object,
fully-populated.

Since all of the methods communicate via a RESTy object, it is currently
necessary that the class consuming HTTPResource also consumes JSONy.

=end pod

role HTTPResource is export {
    #| Upload self, given a RESTy client. Returns a Promise that resolves to
    #| self. Not all resources can be created.
    method create(RESTy $rest) {
        my $endpoint = endpoint-for(self, 'create');
        $rest.send($endpoint, self);
    }

    #| Returns a Promise that resolves to a constructed object of this type. Use
    #| named parameters to pass in the data that the C<read> endpoint requires;
    #| usually an ID. Finally, pass in a connected RESTy object.
    method read(::?CLASS:U: %data, RESTy $rest) {
        my $endpoint = endpoint-for(self, 'read', |%data);
        $rest.fetch($endpoint, self, %data);
    }

    #| Updates the resource. Must have an ID already. Returns a Promise for the
    #| operation.
    multi method update(RESTy $rest) {
        my $endpoint = endpoint-for(self, 'update');
        $rest.send($endpoint, self);
    }

    #| Deletes the resource. Must have an ID already. Not all resources can be
    #| deleted. Returns a Promise.
    method delete(RESTy $rest) {
        my $endpoint = endpoint-for(self, 'delete');
        $rest.remove($endpoint);
    }
}

enum OPCODE is export (
    <despatch heartbeat identify status-update
        voice-state-update voice-ping
        resume reconnect
        request-members
        invalid-session hello heartbeat-ack>
);

class HTTPMessage is export {
    has $.source;
    has $.opcode;
    has $.payload;
    has $.sequence;
    has $.event;

    method new($json) {
        my %it; %it<source> = $json;
        %it<opcode> = $json<op>;
        %it<payload> = $json<d>;
        $json<s> andthen %it<sequence> = $_;
        $json<t> andthen %it<event> = $_;

        self.bless(|%it);
    }
}
