# Forge NPWD Shop

Loja de aparelhos e central de recuperacao integrada ao `forge-npwd` e ao `pr_bridge`.

## Recursos

- catalogo configuravel de modelos, cores e precos;
- menu por `pr_lib.menus.RegisterContext`;
- pagamento em dinheiro ou banco;
- reembolso automatico se a entrega falhar;
- emissao de telefone ja registrado com numero, perfil e linha;
- consulta, bloqueio e recuperacao de aparelhos do personagem;
- local, blip, marcador e comando de teste configuraveis.

## Instalacao

Adicione depois do `forge-npwd` no `server.cfg`:

```cfg
ensure forge-npwd
ensure forge-npwd-shop
```

O comando padrao de teste e `/forgephoneshop`.

Edite `config.lua` para alterar modelos, precos, cores, taxa de recuperacao e local da loja.

