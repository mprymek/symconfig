%%% -*- mode: prolog -*-

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXAMPLE GENERATED RULES

%%
%% package repository facts - should be generated from repo data
%%

latest(pkg("nginx","1.6.2_1,2")).
latest(os(freebsd,"10.1-RELEASE-p5")).

pkg_depends(pkg("nginx","1.6.2_1,2"),pkg("expat","2.1.0_2")).
pkg_depends(pkg("nginx","1.6.2_1,2"),pkg("openldap-sasl-client","2.4.40_1")).
pkg_depends(pkg("nginx","1.6.2_1,2"),pkg("pcre","8.35_2")).

%% mtree line: ./nginx.conf-dist type=file uid=0 gid=0 mode=0644 nlink=1 size=2693 time=1411723912.000000000 sha256digest=6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a flags=uarch
file_meta(pkg("nginx","1.6.2_1,2"),"/usr/local/etc/nginx/nginx.conf-dist",file,0,0,644,[uarch],2693,"6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a").

%%
%% os files facts - should be generated from mtree files (see https://github.com/mprymek/mtrees)
%%

%% mtree line:
%%   ./usr/sbin/sshd type=file uid=0 gid=0 mode=0555 size=297792 sha256digest=819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae flags=uarch

%% file_meta(os,path,type,uid,gid,mode,flags,size,sha256)
file_meta(os(freebsd,"10.1-RELEASE-p5"),"/usr/sbin/sshd",file,0,0,555,[uarch],297792,"819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae").
file_meta(os(freebsd,"10.1-RELEASE-p5"),"/etc/ssh/sshd_config",file,0,0,644,[uarch],4034,"26748c51687fe4f09ac6c8ace864d0c545f1fc0aa059bb9bffd80f80c0d62d85").

%%
%% rules generated in the file templating/managing process
%%

latest(patch("patch-nginx.conf","0001")).
peex_managed("/usr/local/etc/nginx/nginx.conf-dist","/usr/local/etc/nginx/nginx.conf","patch-nginx.conf").
patch_cache("6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a","patch sha here","tmplsha1").
eex_cache("tmplsha1","var hash here",2701,"deadbeaf").

latest(patch("patch-sshd_conf","0001")).
peex_managed("/etc/ssh/sshd_config","/etc/ssh/sshd_config","patch-sshd_config").
patch_cache("26748c51687fe4f09ac6c8ace864d0c545f1fc0aa059bb9bffd80f80c0d62d85","patch sha here","tmplsha2").
eex_cache("tmplsha2","var hash here",4046,"ba11ad").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXAMPLE USER-PROVIDED RULES

%%
%% services dependencies - general part, same for all servers
%%

depends(running(svc("nginx")),installed(pkg("nginx",latest))).
depends(running(svc("nginx")),managed(file("/usr/local/etc/nginx/nginx.conf"))).
depends(managed(file("/usr/local/etc/nginx/nginx.conf")),installed(pkg("nginx",latest))).

depends(running(svc("sshd")),managed(file("/etc/ssh/sshd_config"))).
% @TODO: this should be autodetected!
depends(managed(file("/etc/ssh/sshd_config")),installed(os(freebsd,"10.1-RELEASE-p5"))).

%%
%% required state definition for particular server
%%

want(running(svc("nginx"))).
want(running(svc("sshd"))).
want(installed(os(freebsd))).
