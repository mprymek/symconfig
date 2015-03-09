%%% -*- mode: prolog -*-

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXAMPLE GENERATED RULES

%%
%% package repository facts - should be generated from repo data
%%

latest(pkg("nginx","1.6.2_1,2")).

pkg_depends(pkg("nginx","1.6.2_1,2"),pkg("expat","2.1.0_2")).
pkg_depends(pkg("nginx","1.6.2_1,2"),pkg("openldap-sasl-client","2.4.40_1")).
pkg_depends(pkg("nginx","1.6.2_1,2"),pkg("pcre","8.35_2")).

%% mtree line: ./nginx.conf-dist type=file uid=0 gid=0 mode=0644 nlink=1 size=2693 time=1411723912.000000000 sha256digest=6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a flags=uarch
file_meta(pkg("nginx","1.6.2_1,2"),"/usr/local/etc/nginx/nginx.conf-dist",file,0,0,644,[uarch],2693,"6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a").

%%
%% rules generated in the file templating/managing process
%%

latest(patch("patch-nginx.conf","0001")).
peex_managed("/usr/local/etc/nginx/nginx.conf-dist","/usr/local/etc/nginx/nginx.conf","patch-nginx.conf",nginx).
patch_cache("6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a","patch-nginx.conf","tmplsha").
eex_cache("tmplsha","varshash",2701,"deadbeaf").


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXAMPLE USER-PROVIDED RULES

%%
%% services dependencies - general part, same for all servers
%%

depends(running(svc("nginx")),installed(pkg("nginx",latest))).
depends(running(svc("nginx")),managed(file("/usr/local/etc/nginx/nginx.conf"))).
depends(managed(file("/usr/local/etc/nginx/nginx.conf")),installed(pkg("nginx",latest))).

%%
%% required state definition for particular server
%%

varset_hash(nginx,"varshash").

want(running(svc("nginx"))).
