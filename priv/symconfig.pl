%%% -*- mode: prolog -*-

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% UNIVERSAL RULES


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% for swi-prolog

%:- dynamic
%        installed/1,
%        latest/1,
%        pkg_depends/2,
%        file_meta/8,
%        required/1,
%        running/1,
%        detected/1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% for erlog

not(Goal) :- call(Goal),!,fail.
not(Goal).

managed_file_inplace(X) :- fail.
detected(X) :- fail.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% package dependencies - recursive
pkg_depends_r(pkg(A,B),pkg(C,D)) :- pkg_depends(pkg(A,B),pkg(C,D)).
pkg_depends_r(pkg(A,B),pkg(E,F)) :- pkg_depends(pkg(A,B),pkg(C,D)),pkg_depends_r(pkg(C,D),pkg(E,F)).

abbrev(installed(pkg(P)),installed(pkg(P,V))) :- latest(pkg(P,V)).
abbrev(installed(os(P)),installed(os(P,V))) :- latest(os(P,V)).

exp_abbrev(X,X) :- not(abbrev(X,_)).
exp_abbrev(X,Y) :- abbrev(X,Y).

required(Y) :- want(X), exp_abbrev(X,Y).
required(Z) :- depends2(X,Y), exp_abbrev(Y,Z), required(X).

%file_is_managed(MngdF) :-
%   managed_file_src(MngdF,SrcF),
%   justified(sha256(SrcF,SrcS)),
%   managed_file_sha256(SrcS,MngdS),
%   verified(sha256(MngdF,MngdS)).

src2managed(SF,SS,MF,MS) :- managed_file_src(SF,MF), managed_file_sha256(SS,MS).

% TODO: rewrite!
managed(file(F)) :- required(managed(file(F))).

% inject autodependencies
depends2(X,Y) :- depends(X,Y).
% @TODO: this causes infinite loop :(
% @TODO: when we do not find FileSet here, we just lose dependency.
%        This is wrong, we should raise error because dependency is vital here.
%depends2(managed(file(File)),installed(FileSet)) :-
%    managed_file_inplace(File),
%    file_meta(FileSet,File,Type,Uid,Gid,Mode,Flags,Size,OrigSha),
%    justified(installed(FileSet)).


detected2(X) :- detected(X).
detected2(managed(file(F))) :-
    justified(sha256(F,S)), detected2(sha256(F,S)).

%justified(Y) :- exp_abbrev(X,Y), justified(X).
justified(X) :- required(X).
justified(installed(pkg(P2,V2))) :- pkg_depends(pkg(P1,V1),pkg(P2,V2)),justified(installed(pkg(P1,V1))).
justified(file_meta(MngdFile,Type,Uid,Gid,Mode,Flags,Size,MngdSha)) :-
    managed_file_inplace(MngdFile),
    justified(installed(FileSet)),
    managed_file_sha256(OrigSha,MngdSha),
    file_meta(FileSet,MngdFile,Type,Uid,Gid,Mode,Flags,Size,OrigSha).
justified(file_meta(MngdFile,Type,Uid,Gid,Mode,Flags,Size,MngdSha)) :-
    src2managed(SrcFile,SrcSha,MngdFile,MngdSha),
    justified(installed(FileSet)),
    file_meta(FileSet,SrcFile,Type,Uid,Gid,Mode,Flags,Size,SrcSha).
justified(file_meta(Path,Type,Uid,Gid,Mode,Flags,Size,Sha256)) :-
    justified(installed(FileSet)),
    file_meta(FileSet,Path,Type,Uid,Gid,Mode,Flags,Size,Sha256),
    not(managed(file(Path))).
justified(sha256(File,Sha)) :- justified(file_meta(File,file,_,_,_,_,_,Sha)).

justified(B) :- depends(A,B),justified(A).

verified(X) :- detected2(X).
verified(X) :- abbrev(X,Y), verified(Y).

%% print item nicely
nice_print(installed(pkg(Pkg,Ver))) :- writef("Install package %w-%w.\n",[Pkg,Ver]),!.
nice_print(running(svc(Svc))) :- writef("Start service %w.\n",[Svc]),!.
nice_print(managed(file(F))) :- writef("Manage file %w.\n",[F]),!.
nice_print(X) :- writef("%t\n",[X]).

%% what should be changed to achieve the justified state
unjustified(X) :- detected2(X),not(justified(X)).
unverified(X) :- required(X),not(detected2(X)).
all_verified :- not(unverified(X)).
all_justified :- not(unjustified(X)).

print_unverified :- unverified(X),nice_print(X),fail.

%% what is ready to be done
prepared_verifications(X) :- unverified(X),not((depends(X,Y),not(verified(Y)))).

prepared_actions1(verify(sha256(F,S))) :-
    prepared_verifications(managed(file(F))),
    justified(sha256(F,S)).
prepared_actions1(manage(file(F))) :-
    prepared_verifications(managed(file(F))),
    not(justified(sha256(F,_))).
prepared_actions1(verify(X)) :-
    prepared_verifications(X),
    not(X=managed(file(_))).

% to get unique items - disabled for now because setof is not available in erlog
%to_achieve(acceptable_state,Y) :- setof(X, prepared_actions1(X), L),member(Y,L).
to_achieve(acceptable_state,Y) :- prepared_actions1(Y).

in_perfect_state :- all_verified, not(unjustified(X)).
in_acceptable_state :- all_verified.
