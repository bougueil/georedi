ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

all:
# gcc -undefined dynamic_lookup -dynamiclib -o priv/nif.so c_src/nif.c -I"$(ERLANG_PATH)"
# cc -fPIC  -I"$(ERLANG_PATH)" -Wl,-undefined -Wl,dynamic_lookup -shared -o priv/nif.so c_src/nif.c
	g++ -fPIC  -I"$(ERLANG_PATH)"  -Wl,-undefined -Wl,dynamic_lookup -shared  -o  priv/nif.so c_src/nif.c
clean:
	rm  -r "priv/nif.so"
