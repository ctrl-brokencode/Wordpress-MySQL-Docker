# Aplicação Wordpress em AWS

Esse projeto, organizado no Programa de Bolsas da Compass UOL, tem como objetivo subir uma aplicação Wordpress com Docker, fazer conexão dom Banco de Dados RDS e Sistema de Arquivos EFS, controlar o trafégo de internet pelo Load Balancer e Auto Scaling.

# Índice

Se encontre no passo a passo para se guiar!

- [Detalhes da Atividade](#detalhes-da-atividade)
- [VPC (*Virtual Private Cloud*)](#vpc-virtual-private-cloud)
- [Segurity Groups](#security-groups)
- - [Load Balancer](#configuração-do-security-group-do-load-balancer)
- - [Instâncias EC2](#configuração-do-security-group-das-instâncias-ec2)
- - [Banco de Dados](#configuração-do-security-group-do-banco-de-dados)
- - [Sistema de Arquivos](#configuração-do-security-group-do-sistema-de-arquivos)
- [EFS (*Elastic File System*)](#efs-elastic-file-system)
- [RDS (*Relational Database Service*)](#banco-de-dados-rds-relational-database-service)
- [EC2 (*Elastic Compute Cloud*) - Modelo de Execução](#ec2-elastic-compute-cloud---modelo-de-execução)
- - [O que é esse user_data.sh?](#o-que-é-esse-user_datash)
- [Grupo de Destino (*Target Group*)](#grupo-de-destino-target-group)
- [Balanceador de Carga (*Load Balancer*)](#balanceador-de-carga-load-balancer)
- [Escalonamento Automático (*Auto Scaling*)](#escalonamento-automático-auto-scaling)
- [Testando o wordpress](#testando-o-wordpress)

# Detalhes da Atividade

Precisamos subir um container com Docker do Wordpress e fazer este se conectar com o Banco de Dados RDS da AWS. Além disso, precisamos configurar o uso do serviço EFS AWS para armazenar arquivos estáticos do container e também configurar o LoadBalancer para acessar a aplicação através de usa DNS, afim de deixar as outras instâncias privadas. Por fim, vamos deixar nossa aplicação sempre funcionando com o Auto Scaling, para que o site continue no ar mesmo quando alguma instância falhar.

# VPC (*Virtual Private Cloud*)

Uma VPC é uma rede virtual privada na nuvem que permite criar e gerenciar recursos de rede, como sub-redes, tabelas de roteamento e grupos de segurança, de forma isolada e segura. Nós vamos criar uma VPC para o escopo do nosso projeto.

- Siga pra a página de VPC e clique em **Criar VPC**

- - **Recursos a serem criados**: VPC e muito mais
- - **Geração automática da etiqueta de nome**: Deixe a checkbox **Gerar automaticamente** habilitada
- - Nomeie sua VPC (meu caso: wp-project)
- - **Bloco CIDR IPv4**: 10.0.0.0/16
- - **Bloco CIDR IPv6**: Nenhum bloco CIDR IPv6
- - **Número de zonas de disponibilidade (AZs)**: 2
- - **Número de sub-redes públicas**: 2
- - **Número de sub-redes privadas**: 2
- - **Gateways NAT (USD)**: Em 1 AZ
- - **Endpoints da VPC**: Nenhuma
- - **Opções de DNS**: Habilitar nomes de host DNS & Habilitar resolução de DNS
- - Clique em **Criar VPC**

*O processo de ativação de gateways NAT é um pouco demorado. Relaxe, não é sua internet!*

# Security Groups

Nosso próximo passo agora é a criação dos *Security Groups* (Grupos de Segurança). um conjunto de regras de segurança que controlam o tráfego de rede para uma instância EC2 ou outros recursos da AWS, permitindo ou bloqueando o acesso a determinadas portas e protocolos. Logo, antes de criarmos as instâncias, banco de dados e o restante, temos que criar os grupos de segurança para cada uma delas.

- Vá para a página EC2 e procure no menu lateral esquerdo por **Security groups**
- Aperte no botão **Criar grupo de segurança**

## Configuração do Security Group do Load Balancer

- **Nome**: wp-load-balancer-sg
- Dê uma descrição para ele
- **VPC**: Insira sua VPC criada no passo anterior (meu caso: wp-project-vpc)
- **Inbound Rules / Regras de Entrada**:

| Tipo  | Protocolo | Intervalo de Portas | Origem    |
|-------|-----------|---------------------|-----------|
| HTTP  | TCP       | 80                  | 0.0.0.0/0 |

Essa regra permite que Load Balancer aceite o tráfego HTTP na porta 80 de qualquer origem. Nós vamos usar a DNS do Load Balancer e acessá-la no navegador. Ele vai receber a solicitação e encaminhar para a instância EC2, que está rodando o Wordpress.

## Configuração do Security Group das Instâncias EC2

- **Nome**: wp-ec2-instance-sg
- Dê uma descrição para ele
- **VPC**: Insira sua VPC criada no passo anterior (meu caso: wp-project-vpc)
- **Inbound Rules / Regras de Entrada**:

| Tipo  | Protocolo | Intervalo de Portas | Origem              |
|-------|-----------|---------------------|---------------------|
| HTTP  | TCP       | 80                  | wp-load-balancer-sg |

Essa regra permite que o Load Balancer (indicado na Origem) envie o tráfego HTTP para a instância EC2 na porta 80, o do Wordpress. Como nossa instância será privada, não podemos acessar a aplicação diretamente pelo seu IP público. Por isso, usaremos o Load Balancer como intermediário para as requisições.


## Configuração do Security Group do Banco de Dados

- **Nome**: wp-database-sg
- Dê uma descrição para ele
- **VPC**: Insira sua VPC criada no passo anterior (meu caso: wp-project-vpc)
- **Inbound Rules / Regras de Entrada**:

| Tipo          | Protocolo | Intervalo de Portas | Origem                       |
|---------------|-----------|---------------------|------------------------------|
| MYSQL/Aurora  | TCP       | 3306                | wp-ec2-instance-sg           |

Essa regra permite que a Instância EC2 (indicado na Origem) se conecte ao Banco de Dados RDS na porta 3306, padrão para o MySQL ou Aurora. Como o Wordpress precisa acessar o banco de dados, essa configuração garante que suas requisições possam vir da EC2 até chegar no RDS. 

## Configuração do Security Group do Sistema de Arquivos

- **Nome**: wp-file-system-sg
- Dê uma descrição para ele
- **VPC**: Insira sua VPC criada no passo anterior (meu caso: wp-project-vpc)
- **Inbound Rules / Regras de Entrada**:

| Tipo          | Protocolo | Intervalo de Portas | Origem                       |
|---------------|-----------|---------------------|------------------------------|
| NFS           | TCP       | 2049                | wp-ec2-instance-sg           | 

Essa regra permite que a Instância EC2 (indicado na Otigem) se conecte com o Sistema de Arquivos EFS na porta 2049, padrão do NFS (*Network File System*). O EFS armazena os arquivos compartilhados entre as instâncias EC2, não havendo perda de arquivos caso uma instância falhe. 

# EFS (*Elastic File System*)

Com nossos grupos configurados, vamos começar criando o **EFS**, um sistema de arquivos na nuvem que permite que você compartilhe arquivos entre as instâncias EC2 e outros recursos da AWS. Faremos isso para compartilhar arquivos entre as outras instâncias ativas. Aqui, o Wordpress guardará arquivos como imagens, vídeos, temas e plugins.

- Vá para a página do **EFS**, clique em **Criar sistema de arquivos** e siga pra a página de **personalizar**
- - Na página de **Configuração Geral**, não foi alterado nada além do Nome (primeiro campo, meu caso: wp-file-system). Siga para a próxima página.
- - **Virtual Private Cloud (VPC)**: Selecione a [VPC criada anteriormente](#vpc-virtual-private-cloud)
- - **Destinos de Montagem**: Coloque as duas **Zonas de Disponibilidade**, se certifique que as sub-redes de ambas são as sub-redes privadas e altere os **Grupos de segurança** para o [grupo que foi criado para o EFS](#configuração-do-security-group-do-sistema-de-arquivos). Siga para a próxima página.
- - A página de **Política do sistema de arquivos** também não foi alterada. Siga com a criação do sistema.

Após a criação do EFS, clique no nome ou no ID que foi dado à ele e anote o **Nome de DNS**. Você vai precisar dele mais tarde. Feito isso, clique no botão **Anexar** no lado superior direito da tela. Clique na opção **Montar via DNS**, copie o comando que diz **Usando o cliente do NFS** e guarde ele também. Nós o utilizaremos mais tarde.

# Banco de Dados RDS (*Relational Database Service*)

Agora vamos fazer a criação do Banco de Dados. Esse serviço permite criar e gerenciar bancos de dados relacionais na nuvem, oferecendo escalabilidade, segurança e alta disponibilidade. Vamos usar ele para o Wordpress armazenar dados de forma estruturada, facilitando nas consultas e gereciamento do conteúdo do site.

- Siga para a página de RDS e clique no botão **Criar banco de dados**
- - **Tipo de mecanismo**: MySQL
- - **Versão do MySQL**: 8.0.39
- - **Modelo**: Nível gratuito
- - Dê um nome para o **Identificador da instância do banco de dados** (meu caso: wp-database)
- - Dê um **Nome do usuário principal** (meu caso: admin) 🔄
- - **Gerenciamento de credenciais**: **Autogerenciada**
- - Insira uma **Senha principal** e confirme ela 🔄
- - **Configuração da instância**: db.t3.micro
- - **Armazenamento**: SSD de uso geral (gp2) / 20 GiB
- - **Recurso de Computação**: Não se conectar a um recurso de computação do EC2 (iremos fazer isso por meio de [Security Groups](#security-groups) já criados)
- - **Nuvem privada virtual (VPC)**: Selecione sua [VPC criada anteriormente](#vpc-virtual-private-cloud) (meu caso: wp-project-vpc)
- - **Acesso público**: Não
- - **Grupo de segurança de VPC (firewall)**: Selecione o [grupo de segurança criado anteriormente](#configuração-do-security-group-do-banco-de-dados) (meu caso: wp-database-sg)
- - **Zona de disponibilidade**: Sem preferência
- - **Configuração adicional > Nome do banco de dados inicial**: Nomeie seu banco de dados (meu caso: wordpressdb) 🔄

*⚠ Os itens com 🔄 serão reutilizados mais tarde. Anote eles!*

Clique em **Criar banco de dados**. Vai aparecer uma janela de complementos, no qual você pode só fechar. Esse serviço vai demorar para inicializar, então vamos dar seguimento ao projeto.

Enquanto continuamos, volte para a página do Banco de Dados de tempos em tempos, clique no seu **Identificador de banco de dados** (o nome que você deu pra instância) e localize seu **Endpoint**. Por hora, ele não vai existir, mas quando aparecer, deixe anotado também. Vamos precisar daqui a pouco.

# EC2 (*Elastic Compute Cloud*) - Modelo de execução

E finalmente, vamos a criação da EC2. Uma instância EC2 é uma máquina virtual na nuvem que pode ser configurada e personalizada para atender às necessidades específicas de uma aplicação ou serviço.

- Vá na página da EC2 e localize no menu lateral esquerdo os **Modelos de execução**, clicando em **Criar modelo de execução** logo após.

- - Dê um **Nome do modelo de execução** (meu caso: wp-ec2-template)
- - Dê uma **Descrição da versão do modelo** (você pode fazer um versionamento aqui, tipo v1, v2, etc)
- - **Orientação sobre o Auto Scaling**: Habilite a caixa de seleção
- - **Imagem de aplicação e de sistema operacional**: Início rápido > Ubuntu Server 24.04 LTS (HVM)
- - **Arquitetura**: 64 bits (x86)
- - **Tipo de Instância**: t2.micro
- - **Sub-rede**: Não incluir no modelo de execução
- - **Firewall (grupos de segurança)**: Selecione grupo de securança existente - Selecione o [grupo de segurança criado anteriormente](#configuração-do-security-group-das-instâncias-ec2) (meu caso: wp-ec2-instance-sg)
- - **Configuração avançada de rede**: Caso não tenha, clique em **Adicionar interface de rede**. Não precisamos alterar nada aqui
- - **EBS Volumes**: Clique no Volume 1 e altere o **Tipo de volume** para **gp2**
- - **Tags de Recurso**: Fornecidas pela Compass para realização do Projeto, apenas a tag Name sendo personalizada
- - **Detalhes avançados > Dados do usuário**: Insira o arquivo [user_data.sh](#o-que-é-esse-user_datash)

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

# Grupo de Destino (*Target Group*)

Antes da criação do Load Balancer, precisamos criar um Grupo de Destino, permitindo associar um Load Balancer a uma ou mais instâncias EC2, permitindo que o tráfego de rede seja distribuído entre elas. No contexto do projeto, o Grupo de Destino será associado ao Load Balancer para que ele possa encaminhar as requisições HTTP para a instância EC2 que está executando o Wordpress.

- Vá na página da EC2 e localize no menu lateral esquerdo os **Grupos de destino**, clicando em **Criar grupo de destino** logo após.
- - **Escolha um tipo de destino**: Instâncias
- - Dê um **None do grupo de destino** (meu caso: wp-target-group)
- - **Protocolo : Porta**: HTTP : 80
- - **Tipo de edenreço IP**: IPv4
- - **VPC**: Selecione sua [VPC criada anteriormente](#vpc-virtual-private-cloud)
- - **Versão do protocolo**: HTTP1
- - **Configurações avançadas de verificação de integridade > Códigos de sucesso**: 200,302 
- - - Isso é para os códigos de saída que as instâncias vão receber. A saída 200 indica que o Wordpress está OK, enquanto a saída 302 indica que o wordpress está aguardando configuração (página de login) 
- - Clique em **Próximo**. Nessa página, não vamos colocar nenhum destino (estes devem estar vazios). Siga com a criação do grupo de destino

# Balanceador de Carga (*Load Balancer*)

Agora sim vamos fazer a aplicação subir com a DNS do nosso Balanceador de Carga. Um Load Balancer distribui o tráfego de rede de entrada entre várias instâncias EC2, melhorando a escalabilidade e a disponibilidade da aplicação. Como o próprio nome diz, ele distribui a carga.

- Vá na página da EC2 e localize no menu lateral esquerdo os **Load Balancers**, clicando em **Criar load balancer** logo após.
- - **Tipo de Load Balancer**: Application Load Balancer
- - Dê um **Nome do load balancer** (meu caso: wp-load-balancer)
- - **Esquema**: Voltado para a Internet
- - **Tipo de endereço IP do balanceador de carga**: IPv4
- - **Mapeamento de rede**: Selecione a [VPC criada anteriormente](#vpc-virtual-private-cloud) e suas Zonas de Disponibilidade. Lembre de colocar as sub-redes públicas!
- - **Grupos de segurança**: Selecione a [security group criada anteriormente](#configuração-do-security-group-do-load-balancer)
- - **Listeners e roteamento**: Protocolo HTTP na Porta 80. Em **Ação Padrão**, selecione o [grupo de destino](#grupo-de-destino-target-group) criado
- - Em análise, no fim da página, verifique se as informações acima estão corretas e depois crie o Load Balancer

# Escalonamento Automático (*Auto Scaling*)

A última etapa! Vamos garantir que nosso sistema esteja sempre funcionando.
O Auto Scaling permite aumentar ou diminuir automaticamente o número de instâncias EC2 em execução com base em algumas condições específicas, tipo demanda de tráfego e utilização de recursos. Isso ajuda a garantir que a aplicação esteja sempre disponível e escalável, sem a necessidade de termos que verificar manualmente.

- Vá na página da EC2 e localize no menu lateral esquerdo os **Grupos Auto Scaling**, clicando em **Criar grupo do Auto Scaling** logo após.
- - Dê um **Nome do grupo do Auto Scaling** (meu caso: wp-auto-scale)
- - **Modelo de Execução**: Selecione o [modelo de execução criado anteriormente](#ec2---modelo-de-execução) e sua versão
- - **Próxima página**
- - **VPC**: Seleciona a [VPC criada anteriormente](#vpc-virtual-private-cloud)
- - **Zonas de disponibilidade e sub-redes**: Selecione as sub-redes privadas
- - **Distribuição da zona de disponibilidade**: Melhor esforço equilibrado
- - **Próxima página**
- - **Balanceamento de carga**: Anexar a um balanceador de carga existente
- - **Anexar a um balanceador de carga existente**: Selecione o [Load Balancer criado na etapa anterior](#balanceador-de-carga--load-balancer) (também pode ser feito com um **Classic Load Balancer**)
- - **Próxima página**
- - **Capacidade desejada**: 2
- - **Capacidade mínima desejada**: 2
- - **Capacidade máxima desejada**: 3
- - **Pule para a revisão** e verifique se está tudo certo. Crie seu auto scaling.

Você vai precisar aguardar alguns minutos, pois os Target Groups definirão suas instãncias como **Não íntegras** ou ***Unhealthy***, já que estes estão em processo de configuração (instalação de pacotes e do Docker e subir o container do Wordpress). Sò verifique no **Target Group** selecionando o seu que foi [criado anteriormente](#grupo-de-destino-target-group) e vá na páginad de **Destinos**. Se a mensagem de Não íntegro for *Health checks failed*, então está no caminho certo. Se for outra mensagem, o erro é outro. Atualize o **Target Group** em alguns minutos e eles devem ser classificados como **Íntegro** ou ***Healthy***, como era o esperado.

# Testando o Wordpress

Agora que o Load Balancer foi criado, podemos testar a aplicação! Na página de Load Balancers, copie o **Nome do DNS** do Load Balancer criado agora, e cole no navegador. Se tudo estiver correto, você deve ver a página de login do Wordpress.
