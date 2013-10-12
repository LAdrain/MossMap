#!/usr/bin/perl
# This is a Mojolicious web app for accessing and managing the moss
# map.  Much of the map is javascript driven, so doesn't need much
# server-side dynamism, but some things, like uploading and managing
# data-sets, do need some dynamism.
use Mojolicious::Lite;
use Mojolicious::Plugin::Authentication;
use MossMap::Model;


my %users = (
    user1 => {password => 'secret'},
);

plugin authentication => {
    session_key => 'moss-map',
    load_user => sub {
        my ($app, $uid) = @_;
        return $users{$uid};
    },
    validate_user => sub {
        my ($app, $username, $password) = @_;
        return $username
            if $users{$username}
            && $users{$username}{password} eq $password;
        return undef;
    },
};

my $db_path = $ENV{MOSSMAP_DB} || app->home->rel_file('db/moss-map.db');
my $model = MossMap::Model->new($db_path);
helper model => sub {
    my $self = shift;

    return $model;
};

any '/unauthorized' => sub {
    my $self = shift;
    $self->respond_to(
        any => {status => 401,
                text => "Log in via <a href='/login.html'>/login.html</a>"},
        json => {status => 401,
                 json => {error => "Unauthorized"}},
    );
};


group {

    under '/data' => sub {
        my $self = shift;
        # GET requests require no authentication
        return 1 if $self->req->method eq 'GET';

        # Otherwise, insist on it, sending a 401 Unauthorized
        # otherwise

        return 1 if $self->is_user_authenticated;

        $self->render(json  => {error => "Unauthorized"},
                      status => 401);
        return;
    };


    # FIXME error handling?
    # fixme return 20x statuses?

    # get all sets
    get '/sets' => sub {
        my $self = shift;
        $self->respond_to(
            any => {json => $self->model->data_sets,
                    status => 200},
        );
    };
    
    # create a data set
    # FIXME csv version required
    post '/sets' => sub {
        my $self = shift;
        my $data = $self->req->json;
        # force creation rather than modification of any existing set
        delete $data->{id}; 
        my $id = $self->model->new_data_set($data);

        $self->respond_to(
            any => {json => {message => "ok", id => $id},
                    status => 201},
        );
    };

    # query a data set
    # FIXME csv version required
    get '/set/:id' => sub {
        my $self = shift;
        my $id = $self->param('id');  
        my $data = $self->model->get_data_set($id);
        if ($data) {
            $self->respond_to(
                any => {json => $data,
                        status => 200},
            );
            return;
        }

        $self->respond_to(
            any => {json => {error => 'Invalid id', id => $id},
                    status => 404},
        );
    };

    # alter data set
    # FIXME csv version required
    put '/set/:id' => sub {
        my $self = shift;
        my $id = $self->param('id');  
        my $data = $self->req->json;
        $data->{id} = $id;
        $self->model->set_data_set($data);
        $self->respond_to(
            any => {json => {message => "ok", id => $id},
                    status => 200},
        );
    };

    # remove a data set
    del 'set/:id' => sub {
        # remove set
        my $self = shift;
        my $id = $self->param('id');
        $self->model->delete_data_set($id);
        $self->respond_to(
            any => {json => {message => "ok", id => $id},
                    status => 200},
        );
    };
};

post 'login.json' => sub {
    my $self = shift;
    my $data = $self->req->json;
    if ($self->authenticate($data->{user}, $data->{password})) {
        $self->render(json => {message => 'ok'});
    }
    else {
        $self->render(json => {error => 'Login failed'},
                      status => 401);
    }
};




%Test::Mojo:: or app->start;

__DATA__



__END__

static stuff gets served as is,

index.html -> index.html, etc.

dynamic API:

# set/taxon/gridref/date/who
GET  data/set - show uploaded data sets
GET  data/set/:setid - show uploaded data set
GET  data/set/:setid/:taxon - show taxon data
GET  data/set/:setid/:taxon/:gridref - show taxon data
GET  data/set/:setid/:taxon/:gridref/:date - show taxon data
GET  data/set/:setid/:taxon/:gridref/:date/:index - show taxon data

PUT data/set/:setid - create/modify data
PUT data/set/:setid/... - modify data

DELETE data/set/:setid - delete data
DELETE data/set/:setid/... - delete data


GET login
POST login
POST logout

