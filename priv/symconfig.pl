%%% -*- mode: prolog -*-

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% UNIVERSAL RULES


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% for swi-prolog

%:- dynamic
%        latest/1,
%        pkg_depends/2,
%        file_meta/9,
%        required/1,
%        running/1,
%        detected/1,
%        want/1,
%        depends/2,
%        peex_managed/3,
%        patch_cache/3,
%        eex_cache/4.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% for erlog

not(Goal) :- call(Goal),!,fail.
not(Goal).

latest(_) :- fail.
pkg_depends(_,_) :- fail.
file_meta(_,_,_,_,_,_,_,_,_) :- fail.
detected(_) :- fail.
want(_) :- fail.
depends(_,_) :- fail.
peex_managed(_,_,_) :- fail.
patch_cache(_,_,_) :- fail.
eex_cache(_,_,_,_) :- fail.

throw(X) :- ecall(symconfig_helper:error(X),_Y).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% symbolic1 targets:
%   installed(pkg(Pkg,latest))
%   installed(os(Os,latest))
%   managed(File)
%   peex_managed(File)
%
% definite targets:
%   file_meta(File,Type,Uid,Gid,Mode,Flags,Size,Sha256)
%   installed(pkg(Pkg,Version))
%   installed(os(Os,Version))
%

%% package dependencies - recursive
pkg_depends_r(pkg(A,B),pkg(C,D)) :- pkg_depends(pkg(A,B),pkg(C,D)).
pkg_depends_r(pkg(A,B),pkg(E,F)) :- pkg_depends(pkg(A,B),pkg(C,D)),pkg_depends_r(pkg(C,D),pkg(E,F)).

% target is symbolic1 = its expansion is based solely on generated rules
symbolic1(installed(pkg(P,latest)),installed(pkg(P,V))) :- latest(pkg(P,V)),!.
symbolic1(installed(os(P,latest)),installed(os(P,V))) :- latest(os(P,V)),!.
symbolic1(installed(os(P)),installed(os(P,V))) :- latest(os(P,V)),!.

% expand symbolic1 targets to definite ones
exp_symbolic1(X,Y) :- symbolic1(X,Y),!.
exp_symbolic1(X,X).

% target is symbolic2 = its expansion is based on justified/1 or similar problematic predicates
% which could potentially cause loops
symbolic2(managed(file(DstFile)),file_meta(DstFile,Type,Uid,Gid,Mode,Flags,Size,MngdSha)) :-
    mngd_layer(file_meta(DstFile,Type,Uid,Gid,Mode,Flags,Size,MngdSha)),
    !.
symbolic2(managed(file(DstFile)),cache_miss(eex_cache(TemplSha,"vars hash here",unknown,unknown))) :-
    peex_managed(SrcFile,DstFile,_PatchId),
    os_pkg_layer(file_meta(SrcFile,_,_,_,_,_,_,SrcSha)),
    patch_cache(SrcSha,_PatchId,TemplSha),
    !.
symbolic2(managed(file(DstFile)),cache_miss(patch_cache(SrcFile,SrcSha,PatchId,PatchVer))) :-
    peex_managed(SrcFile,DstFile,PatchId),
    latest(patch(PatchId,PatchVer)),
    os_pkg_layer(file_meta(SrcFile,_,_,_,_,_,_,SrcSha)),
    !.
% @TODO: when latest_patch fact is missing, we get unknown src
symbolic2(managed(file(DstFile)),error(unknown_src_file(SrcFile))) :-
    peex_managed(SrcFile,DstFile,_PatchId),
    !.

exp_symbolic2(X,Y) :- symbolic2(X,Y),!.
exp_symbolic2(X,X).

% inject autodependencies
depends2(X,Y) :- depends(X,Y).
% we suppose package dependencies are handled by OS's package manager...
%depends2(installed(pkg(PA,VA)),installed(pkg(PB,VB))) :- pkg_depends(pkg(PA,VA),pkg(PB,VB)).
%depends2(file_meta(DstFile,Type,Uid,Gid,Mode,Flags,Size,_MngdSha),installed(FileSet)) :-

% TODO: different layers?!
depends2(file_meta(DstFile,_,_,_,_,_,_,_),installed(FileSet)) :-
    managed(SrcFile,DstFile),
    file_meta(FileSet,SrcFile,Type,Uid,Gid,Mode,Flags,Size,_SrcSha).

% @TODO: this causes infinite loop :(
% @TODO: when we do not find the FileSet here, we just lose dependency.
%        This is wrong, we should raise an exception because dependency is vital here.
%depends2(managed(file(File)),installed(FileSet)) :-
%    managed_file_inplace(File),
%    file_meta(FileSet,File,Type,Uid,Gid,Mode,Flags,Size,OrigSha),
%    justified(installed(FileSet)).

required(C) :- want(A), exp_symbolic1(A,B), exp_symbolic2(B,C).
required(D) :- depends2(A,B), exp_symbolic1(B,C), exp_symbolic2(C,D), required(A).

detected2(X) :- detected(X).
detected2(Y) :- detected(X),symbolic1(Y,X).
detected2(Y) :- detected(X),symbolic2(Y,X).
detected2(Y) :- detected(X),symbolic1(X,Y).
detected2(Y) :- detected(X),symbolic2(X,Y).

%%justified(Y) :- exp_symbolic1(X,Y), justified(X).
justified(X) :- required(X).
justified(FileMeta) :- top_layer(FileMeta).

managed(SrcFile,DstFile) :- peex_managed(SrcFile,DstFile,_PatchId),!.

peex_cache(SrcSha,PatchId,TemplSha,VarsHash,DstSize,DstSha) :-
    patch_cache(SrcSha,PatchId,TemplSha),
    eex_cache(TemplSha,VarsHash,DstSize,DstSha).

% os_layer + pkg_layer + mngd_layer
top_layer(FileMeta) :- mngd_layer(FileMeta).
top_layer(file_meta(Path,Type,Uid,Gid,Mode,Flags,Size,Sha256)) :-
    os_pkg_layer(file_meta(Path,Type,Uid,Gid,Mode,Flags,Size,Sha256)),
    not(mngd_layer(file_meta(Path,_,_,_,_,_,_,_))).

mngd_layer(file_meta(DstFile,Type,Uid,Gid,Mode,Flags,MngdSize,MngdSha)) :-
    peex_managed(SrcFile,DstFile,_PatchId),
    peex_cache(SrcSha,_,_,_,MngdSize,MngdSha),
    os_pkg_layer(file_meta(SrcFile,Type,Uid,Gid,Mode,Flags,_Size,SrcSha)).

% os layer + pkg layer
os_pkg_layer(FileMeta) :- pkg_layer(FileMeta).
os_pkg_layer(FileMeta) :- os_layer(FileMeta).

pkg_layer(file_meta(Path,Type,Uid,Gid,Mode,Flags,Size,Sha256)) :-
    justified(installed(pkg(P,V))),
    file_meta(pkg(P,V),Path,Type,Uid,Gid,Mode,Flags,Size,Sha256).

os_layer(file_meta(Path,Type,Uid,Gid,Mode,Flags,Size,Sha256)) :-
    required(installed(os(O,V))),
    file_meta(os(O,V),Path,Type,Uid,Gid,Mode,Flags,Size,Sha256).

verified(X) :- detected2(X).

%% print item nicely
nice_print(installed(pkg(Pkg,Ver))) :- writef("Package %w-%w is installed.\n",[Pkg,Ver]),!.
nice_print(running(svc(Svc))) :- writef("Service %w is running.\n",[Svc]),!.
nice_print(managed(file(F))) :- writef("File %w is managed.\n",[F]),!.
nice_print(X) :- writef("%t\n",[X]).

%% what should be changed to achieve the justified state
unjustified(X) :- detected2(X),not(justified(X)).
unverified(X) :- required(X),not(detected2(X)).
all_verified :- not(unverified(_)).
all_justified :- not(unjustified(_)).

print_unverified :- unverified(X),nice_print(X),fail.

%% what is ready to be done
prepared_verifications(X) :- unverified(X),not((depends2(X,Y),not(verified(Y)))).

to_action(cache_miss(X),fill_cache(X)) :- !.
to_action(X,verify(X)).

%prepared_actions1(verify(file_meta(F,Type,Uid,Gid,Mode,Flags,Size,Sha256))) :-
%  prepared_verifications(managed(file(F))),
%  mngd_layer(file_meta(F,Type,Uid,Gid,Mode,Flags,Size,Sha256)).
%prepared_actions1(verify(X)) :-
%  prepared_verifications(X),
%  not(X=managed(file(_))).
%prepared_actions1(verify(X)) :-
%  prepared_verifications(X).
prepared_actions(C) :-
  prepared_verifications(A),
  exp_symbolic2(A,B),
  to_action(B,C).

% to get unique items - disabled for now because setof is not available in erlog
%to_achieve(acceptable_state,Y) :- setof(X, prepared_actions1(X), L),member(Y,L).
to_achieve(acceptable_state,Y) :- prepared_actions(Y).

in_perfect_state :- all_verified, not(unjustified(_)).
in_acceptable_state :- all_verified.
