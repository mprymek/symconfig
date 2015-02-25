%%% -*- mode: prolog -*-

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% UNIVERSAL RULES

:- dynamic
        installed/1,
        latest/1,
        pkg_depends/2,
        file_meta/8,
        managed_file/1,
        required/1,
        running/1,
        detected/1.


%% package dependencies - recursive
pkg_depends_r(pkg(A,B),pkg(C,D)) :- pkg_depends(pkg(A,B),pkg(C,D)).
pkg_depends_r(pkg(A,B),pkg(E,F)) :- pkg_depends(pkg(A,B),pkg(C,D)),pkg_depends_r(pkg(C,D),pkg(E,F)).

abbrev(installed(pkg(P)),installed(pkg(P,V))) :- latest(pkg(P,V)).

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

managed_file(F) :- required(managed_file(F)).

% inject autodependencies
depends2(X,Y) :- depends(X,Y).

detected2(X) :- detected(X).
detected2(managed_file(F)) :-
  justified(sha256(F,S)), detected2(sha256(F,S)).

%justified(Y) :- abbrev(X,Y), justified(X).
justified(X) :- required(X).
justified(installed(pkg(P2,V2))) :- pkg_depends(pkg(P1,V1),pkg(P2,V2)),justified(installed(pkg(P1,V1))).
justified(file_meta(Path,Type,Uid,Gid,Mode,Flags,Size,Sha256)) :- not(managed_file(Path)),
    justified(installed(X)), file_meta(X,Path,Type,Uid,Gid,Mode,Flags,Size,Sha256).
justified(sha256(MF,MS)) :- src2managed(SF,SS,MF,MS), justified(sha256(SF,SS)).
justified(sha256(F,S)) :- justified(file_meta(F,file,_,_,_,_,_,S)).

justified(B) :- depends(A,B),justified(A).

verified(X) :- detected2(X).
verified(X) :- abbrev(X,Y), verified(Y).

%% print item nicely
nice_print(installed(pkg(Pkg,Ver))) :- writef("Install package %w-%w.\n",[Pkg,Ver]),!.
nice_print(running(svc(Svc))) :- writef("Start service %w.\n",[Svc]),!.
nice_print(managed_file(F)) :- writef("Manage file %w.\n",[F]),!.
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
    prepared_verifications(managed_file(F)),
    justified(sha256(F,S)).
prepared_actions1(manage_file(F)) :-
    prepared_verifications(managed_file(F)),
    not(justified(sha256(F,_))).
prepared_actions1(verify(X)) :-
    prepared_verifications(X),
    not(X=managed_file(_)).

% to get unique items
to_achieve(acceptable_state,Y) :- setof(X, prepared_actions1(X), L),member(Y,L).

in_perfect_state :- all_verified, not(unjustified(X)).
in_acceptable_state :- all_verified.
