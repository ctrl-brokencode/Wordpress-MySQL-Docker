# Aplicação Wordpress com Banco de Dados MySQL com Docker

Esse projeto organizado no Programa de Bolsas da Compass UOL tem como objetivo subir uma aplicação Wordpress com um Banco de Dados MySQL com Docker.

# Índice

Se encontre no passo a passo para se guiar!

- [Detalhes da Atividade](#detalhes-da-atividade)
- [Segurity Group](#segurity-group)
- - [Load Balancer](#security-group-do-load-balancer)
- - [Aplicação](#security-group-da-aplicação)
- [RDS](#banco-de-dados-rds-relational-database-service)
- - [Configuração](#configuração-do-rds)
- [EFS](#efs-elastic-file-system)
- - [Configuração](#configuração-do-efs)
- [EC2](#ec2)
- - [Configuração](#configuração-da-ec2)
- - [O que é esse user_data.sh](#o-que-é-esse-user_datash)
- [Load Balancer](#load-balancer)
- - [Configuração](#configuração-do-load-balancer)
- [Testando a aplicação](#testando-o-wordpress)

# Detalhes da Atividade

Precisamos subir um container com Docker do Wordpress e fazer este se conectar com o Banco de Dados RDS da AWS. Além disso, precisamos configurar o uso do serviço EFS AWS para armazenar arquivos estáticos do container e também configurar o LoadBalancer para acessar a aplicação através de usa DNS, afim de deixar as outras instâncias privadas.

# Security Group

Um *Security Group* (Grupo de Segurança) é um conjunto de regras de segurança que controlam o tráfego de rede para uma instância EC2 ou outros recursos da AWS, permitindo ou bloqueando o acesso a determinadas portas e protocolos.

Logo, antes de criarmos as instâncias, temos que criar dois grupos de segurança, uma para o EC2 e RDS, e outra para o Load Balancer, no qual deve ser criada primeiro.

## Security Group do Load Balancer

- **Inbound Rules / Regras de Entrada**:

| Tipo  | Protocolo | Intervalo de Portas | Origem    |
|-------|-----------|---------------------|-----------|
| HTTP  | TCP       | 80                  | 0.0.0.0/0 |
| HTTPS | TCP       | 443                 | 0.0.0.0/0 | 

Todas essas regras e suas portas serão liberadas para acesso na Instância EC2 através do Load Balancer. Fazer dessa forma permite que o acesso direto à aplicação do Wordpress no navegador seja negado. Ou seja, não vamos utilizar o IPv4 público da instância EC2 para fazer esse acesso, mas sim, usaremos o DNS do Load Balancer, que já vai lidar com esse tráfego de rede.

## Security Group da Aplicação

- **Inbound Rules / Regras de Entrada**:

| Tipo          | Protocolo | Intervalo de Portas | Origem                       |
|---------------|-----------|---------------------|------------------------------|
| HTTPS         | TCP       | 443                 | Security Group Load Balancer | 
| HTTP          | TCP       | 80                  | Security Group Load Balancer | 
| NFS           | TCP       | 2049                | 172.31.0.0/16                | 
| MYSQL/Aurora  | TCP       | 3306                | 172.31.0.0/16                |
| SSH           | TCP       | 20                  | 0.0.0.0/0                    | 

Note que as regras de **HTTPS** e **HTTP** têm suas origens apontadas para o outro Security Group, o do Load Balancer. A Instância também vai se conectar com o EFS e o Banco de Dados

# Banco de Dados RDS (*Relational Database Service*)

Vamos fazer a criação do Banco de Dados primeiro. Essa instância permite criar e gerenciar bancos de dados relacionais na nuvem, oferecendo escalabilidade, segurança e alta disponibilidade.

- Siga para a página de RDS e clique no botão **Criar banco de dados**

## Configuração do RDS

- **Tipo de mecanismo**: MySQL
- **Versão do MySQL**: 8.0.39
- **Modelo**: Nível gratuito
- **Identificador da instância do banco de dados**: wordpress-db
- **Nome do usuário principal**: admin 🔄
- **Senha principal**: ####### 🔄
- **Configuração da instância**: db.t3.micro
- **Armazenamento**: SSD de uso geral (gp2) / 20 GiB
- **Recurso de Computação**: Não se conectar a um recurso de computação do EC2 (iremos fazer isso por meio de [Security Groups](#security-group) já criados)
- **Grupo de segurança de VPC adicional**: wordpress-sg (selecionar o [Security Group](#security-group))
- **Configuração adicional > Nome do banco de dados inicial**: wordpressdb 🔄

⚠ Os itens com 🔄 serão reutilizados mais tarde. Anote eles!

Após a criação do Banco de Dados, clique no seu Identificador (o nome que você deu pra instância) e localize seu endpoint.

# EFS (Elastic File System)

Seguiremos com agora com o **EFS**, um sistema de arquivos na nuvem que permite
que você compartilhe arquivos entre as instâncias EC2 e outros recursos da AWS.
Faremos isso para compartilhar arquivos entre as outras instâncias.

- Vá para a página do **EFS**, clique em **Criar sistema de arquivos** e siga pra a página de **personalizar**.

## Configuração do EFS

- Na página de Configuração Geral, não foi alterado nada além do Nome (primeiro campo). Siga para a próxima página.
- **Virtual Private Cloud (VPC)**: Selecione a sua VPC
- **Destinos de Montagem**: Coloque todas as Zonas de Disponibilidade (us-east-1a até us-east-1f) para a Security Group padrão e vá para a próxima página.
- A página de Política do sistema de arquivos também não foi alterada. Siga com a criação do sistema.

Após a criação do EFS, clique no nome ou no ID que foi dado à ele e anote o **Nome de DNS**. Você vai precisar dele mais tarde. Feito isso, clique no botão **Anexar** no lado superior direito da tela. Copie o comando que diz *Usando o cliente do NFS* e guarde ele também. Nós o utilizaremos mais tarde.

# EC2

E finalmente, vamos a criação da EC2. Uma instância EC2 é uma máquina virtual na nuvem que pode ser configurada e personalizada para atender às necessidades específicas de uma aplicação ou serviço.

- Vá na página da EC2 e clique em **Executar instância**

## Configuração da EC2

- **Nome e Tags**: Fornecidas pela Compass para realização do Projeto, apenas a tag Name sendo personalizada
- **Imagem**: Ubuntu Server 24.04 LTS (HVM)
- **Arquitetura**: 64 bits (x86)
- **Tipo de Instância**: t2.micro
- **Tipo de chaves SSH**: ED25519 (é necessário criar um Par de Chaves para acesso SSH)
- **VPC**: Selecionar a VPC
- **Atribuir IP público automaticamente**: Habilitar
- **Firewall (grupos de segurança)**: wordpress-sg (selecionar o [Security Group](#security-group))
- **Armazenamento**: 1x 8 Gib gp2
- **Detalhes avançados > Dados do usuário**: Insira o arquivo [user_data.sh](#o-que-é-esse-user_datash)

## O que é esse *user_data.sh*?

Basicamente, é um arquivo de configuração no qual será executado junto com a criação da instância. Ele vai instalar o docker e o docker compose, subir a aplicação do wordpress e fazer a montagem do EFS. 

## IMPORTANTE!

Você precisa alterar os valores do seu [user_data.sh](./user_data.sh) com os seus, utilizando aqueles que foi pedido para serem anotados anteriormente. Você vai colocar nesses campos:

```yaml
WORDPRESS_DB_HOST: <rds-endpoint>
WORDPRESS_DB_USER: <database-main-user>
WORDPRESS_DB_PASSWORD: <database-password>
WORDPRESS_DB_NAME: <database-name>
```

Na etapa de criação do [Banco de Dados](#banco-de-dados-rds-relational-database-service), foi pedido que você anotasse os valores para a reutilização deles. É nesses campos acima que você vai colocar.

```sh
# !!! Insira nessa linha o comando copiado em Anexar usando client do NFS "altere o 'efs' para '/mnt/efs' no final"
echo "<EFS-DNS-Name>:/ /mnt/efs nfs defaults,_netdev 0 0" >> /etc/fstab
```

Na etapa de criação do [EFS](#efs-elastic-file-system), foi pedido primeiro o Nome de DNS, no qual você vai substituir esse nome pelo `<EFS-DNS-Name>` indicado na última linha do arquivo, e acima dele, você vai trocar o comentário pela *montagem usando o client do NFS*.

Feito isso, siga com a criação da instância e aguarde alguns minutos.

# Load Balancer

Agora vamos fazer a aplicação subir com a DNS do nosso Balanceador de Carga. Um Load Balancer distribui o tráfego de rede de entrada entre várias instâncias EC2, melhorando a escalabilidade e a disponibilidade da aplicação. Como o próprio nome diz, ele distribui a carga.

- Vá na página do Load Balancer e clique em **Criar load balancer**

## Configuração do Load Balancer

- **Tipo de Load Balancer**: Application Load Balancer
- **Nome do load balancer**: wordpress-lb
- **Esquema**: Voltado para a Internet
- **Tipo de endereço IP do balanceador de carga**: IPv4
- **Mapeamento de rede**: Selecione sua VPC e suas Zonas de Disponibilidade
- **Grupos de segurança**: Selecione a [security group criada especificamente para o Load Balancer](#security-group-do-load-balancer)
- **Listeners e roteamento**: Protocolo HTTP na Porta 80. Aqui precisamos criar um **Target Group**:
- - **Tipo de destino**: Instâncias
- - **Nome do grupo de destino**: wordpress-tg
- - **Tipo de endereço IP**: IPv4
- - **VPC**: Selecione sua VPC
- - **Versão do protocolo**: HTTP1
- - Clique na próxima página
- - **Instâncias disponíveis**: Selecione sua instãncia e clique no botão **Incluir como pendente abaixo**, clicando em **Criar grupo de destino** logo após.
- **Ação padrão**: Com o Grupo de Destino criado, selecione-o no campo
- Em análise, verifique se as informações acima estão corretas e depois crie o Load Balancer

Feito isso, vá na página de Target Groups e clique no grupo criado. Em detalhes, você precisa aguardar o grupo se tornar **Íntegro**, para que ele possa ser acessado.

# Testando o Wordpress

Agora que o Load Balancer foi criado, podemos testar a aplicação! Na página de Load Balancers, copie o **Nome do DNS** do Load Balancer criado agora, e cole no navegador. Se tudo estiver correto, você deve ver a página de login do Wordpress.
