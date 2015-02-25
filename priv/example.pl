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
%% os files facts - should be generated from mtree files (see https://github.com/mprymek/mtrees) 
%%

%% mtree line:
%%   ./usr/sbin/sshd type=file uid=0 gid=0 mode=0555 size=297792 sha256digest=819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae flags=uarch

%% file_meta(os,path,type,uid,gid,mode,flags,size,sha256)
file_meta(os(freebsd,"10.1-RELEASE-p5"),"/usr/sbin/sshd",file,0,0,555,[uarch],297792,"819b1edb37352186f3fdac8fb61010d4008cf93b7093cea6063615c785bfd1ae").

%%
%% rules generated in the file templating/managing process
%%

managed_file_src("/usr/local/etc/nginx/nginx.conf-dist","/usr/local/etc/nginx/nginx.conf").

managed_file_sha256("6418ea5b53e0c2b4e9baa517fce7ccf7619db03af68de7445dccb2c857978a4a","deadbeaf").


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXAMPLE USER-PROVIDED RULES

%%
%% services dependencies - general part, same for all servers
%%

depends(running(svc("nginx")),installed(pkg("nginx"))).
depends(running(svc("nginx")),managed_file("/usr/local/etc/nginx/nginx.conf")).
depends(managed_file("/usr/local/etc/nginx/nginx.conf"),installed(pkg("nginx"))).

%%
%% required state definition for particular server
%%

want(running(svc("nginx"))).
%want(installed(os(freebsd,"10.1-RELEASE-p5"))).
