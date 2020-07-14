unit module API::Discord::Types;

subset Snowflake is export of Str where /^ <[ 0 1 ]> ** 64 $/;

enum CLOSE-EVENT is export (
);


package ChannelType is export {
    enum :: <guild-text dm guild-voice group-dm guild-category> ;
}
