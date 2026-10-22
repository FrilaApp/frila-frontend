#!/usr/bin/env ruby
# Metadados e revisão beta via API. A chave e o JWT existem só na memória.
require 'json'
require 'uri'
require 'net/http'
require 'openssl'
require 'base64'
require 'set'

module AppStoreConnect
  class Erro < StandardError; end
  class ErroAPI < Erro
    attr_reader :status
    def initialize(status)
      @status = status
      super("A API recusou a chamada (HTTP #{status}); confira permissões e o estado do recurso.")
    end
  end

  class Log
    def initialize(out = $stdout, github: ENV['GITHUB_ACTIONS'] == 'true')
      @out, @github, @segredos = out, github, []
    end

    def mask(value)
      return if value.nil? || value.empty? || @segredos.include?(value)
      @segredos << value
      if @github
        escaped = value.gsub('%', '%25').gsub("\r", '%0D').gsub("\n", '%0A')
        @out.puts("::add-mask::#{escaped}")
      end
      value.lines.map(&:strip).reject(&:empty?).each { |line| mask(line) } if value.include?("\n")
    end

    def info(message)
      text = message.to_s.dup
      @segredos.sort_by { |v| -v.length }.each { |v| text.gsub!(v, '***') }
      # Também cobre e-mails retornados pela API que não vieram na entrada.
      text.gsub!(/[^\s"<>]+@[^\s"<>]+/, '***')
      @out.puts(text.gsub(/[\r\n]/, ' '))
    end
  end

  def self.autenticar(env, log, key_reader: ->(p8) { OpenSSL::PKey.read(p8) })
    nomes = {'ASC_KEY_ID'=>'APP_STORE_CONNECT_API_KEY_ID',
      'ASC_ISSUER_ID'=>'APP_STORE_CONNECT_API_ISSUER_ID', 'ASC_KEY_P8'=>'APP_STORE_CONNECT_API_KEY_P8'}
    nomes.each_key { |name| log.mask(env[name]) }
    faltam = nomes.select { |name, _| env[name].to_s.strip.empty? }.values
    raise Erro, "Faltam os segredos #{faltam.join(' ')} (iOS/Docs/CI.md, 'Operar a App Store Connect pela API')" unless faltam.empty?
    begin
      key = key_reader.call(env['ASC_KEY_P8'])
      raise Erro, 'APP_STORE_CONNECT_API_KEY_P8 deve ser uma chave privada EC P-256.' unless key.private? && key.group.curve_name == 'prime256v1'
    rescue OpenSSL::OpenSSLError, ArgumentError, NoMethodError
      raise Erro, 'APP_STORE_CONNECT_API_KEY_P8 inválido; confira o conteúdo completo do .p8.'
    end
    # Team Key: mesmo Key ID, Issuer ID e .p8 usados pelo workflow TestFlight.
    # ES256 e validade abaixo do limite de 20 minutos da Apple; renova em memória.
    token, vencimento = nil, 0
    lambda do
      now = Time.now.to_i
      if now >= vencimento - 30
        encode = ->(obj) { Base64.urlsafe_encode64(JSON.generate(obj), padding: false) }
        header = encode.call({'alg'=>'ES256','kid'=>env['ASC_KEY_ID'],'typ'=>'JWT'})
        payload = encode.call({'iss'=>env['ASC_ISSUER_ID'],'iat'=>now,'exp'=>now + 600,'aud'=>'appstoreconnect-v1'})
        input = "#{header}.#{payload}"
        der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(input))
        signature = OpenSSL::ASN1.decode(der).value.map { |n| [n.value.to_i.to_s(16).rjust(64, '0')].pack('H*') }.join
        raise Erro, 'Assinatura ES256 inválida.' unless signature.bytesize == 64
        token = "#{input}.#{Base64.urlsafe_encode64(signature, padding: false)}"
        vencimento = now + 600
        log.mask(token)
      end
      token
    end
  end

  class Client
    BASE = 'https://api.appstoreconnect.apple.com'.freeze
    def initialize(token:, aplicar: false, transport: nil)
      @token, @aplicar = token, aplicar
      @transport = transport || method(:http)
    end

    def request(method, path, body = nil)
      raise Erro, 'Escrita bloqueada: aplicar=false.' if method != 'GET' && !@aplicar
      uri = URI(path.start_with?('/') ? BASE + path : path)
      unless uri.scheme == 'https' && uri.host == 'api.appstoreconnect.apple.com' && uri.port == 443 && uri.userinfo.nil? && uri.fragment.nil? && uri.path.start_with?('/v1/')
        raise Erro, 'Link da API inválido; token não enviado.'
      end
      klass = {'GET'=>Net::HTTP::Get,'POST'=>Net::HTTP::Post,'PATCH'=>Net::HTTP::Patch}.fetch(method)
      req = klass.new(uri)
      req['Authorization'] = "Bearer #{@token.call}"
      req['Accept'] = 'application/json'
      if body
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)
      end
      response = @transport.call(req)
      raise ErroAPI.new(response.code.to_i) unless (200..299).cover?(response.code.to_i)
      response.body.to_s.empty? ? {} : JSON.parse(response.body)
    rescue JSON::ParserError
      raise Erro, 'A API retornou JSON inválido.'
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::OpenSSLError
      # Mensagens do transporte podem conter URL com e-mail ou detalhes de chave.
      raise Erro, 'Falha de conexão com a API; nenhuma resposta confirmada.'
    end

    def list(path, query = {})
      path += '?' + URI.encode_www_form(query.merge('limit'=>200)) unless query.empty?
      items, visited = [], Set.new
      while path
        raise Erro, 'Paginação repetiu o mesmo link.' unless visited.add?(path)
        result = request('GET', path)
        raise Erro, 'A API não retornou uma lista.' unless result['data'].is_a?(Array)
        items.concat(result['data'])
        path = result.dig('links', 'next')
      end
      items
    end

    private

    def http(req)
      Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true, open_timeout: 15, read_timeout: 45) { |http| http.request(req) }
    end
  end

  class Job
    BUNDLE = 'com.frila.org.app'.freeze
    PAPEIS = %w[ACCOUNT_HOLDER ADMIN APP_MANAGER DEVELOPER MARKETING].freeze
    ITENS_NAO = %w[advertising gambling healthOrWellnessTopics lootBox messagingAndChat parentalControls socialMedia socialMediaAgeRestricted unrestrictedWebAccess].freeze
    ITENS_NENHUM = %w[alcoholTobaccoOrDrugUseOrReferences contests gamblingSimulated gunsOrOtherWeapons medicalOrTreatmentInformation profanityOrCrudeHumor sexualContentGraphicAndNudity sexualContentOrNudity horrorOrFearThemes matureOrSuggestiveThemes violenceCartoonOrFantasy violenceRealisticProlongedGraphicOrSadistic violenceRealistic].freeze

    def initialize(client:, log:, acao:, aplicar:, emails:, grupo:, sem_referencias_alcool:, verificacao_idade:, versao: '0.5.1', limite: '1000', beta_segredos: {})
      @client, @log, @acao, @aplicar = client, log, acao, aplicar
      @grupo, @alcool, @idade = grupo.strip, sem_referencias_alcool, verificacao_idade
      @versao, @limite, @beta_segredos = versao, limite, beta_segredos
      @beta_segredos.each_value { |value| @log.mask(value) }
      # Índices preservam a posição original, inclusive com entrada repetida.
      @emails = emails.to_s.split(/[\s,;]+/).reject(&:empty?).each_with_index.map do |email, i|
        @log.mask(email)
        @log.mask(email.downcase)
        [email.downcase, i + 1]
      end
    end

    def run
      raise Erro, 'Ação inválida.' unless %w[conferir grupo-interno classificacao grupo-externo revisao-beta].include?(@acao)
      @log.info("Ação: #{@acao}; aplicar=#{@aplicar}")
      apps = @client.list('/v1/apps', 'filter[bundleId]'=>BUNDLE, 'fields[apps]'=>'name,bundleId')
      raise Erro, 'App com.frila.org.app não encontrado de forma única.' unless apps.size == 1 && apps[0].dig('attributes','bundleId') == BUNDLE
      @app = apps[0]
      @log.info("App: #{BUNDLE}; id=#{id(@app)}; nome=#{@app.dig('attributes','name')}")
      case @acao
      when 'conferir' then conferir
      when 'grupo-interno' then grupo_interno
      when 'classificacao' then classificacao
      when 'grupo-externo' then grupo_externo
      when 'revisao-beta' then revisao_beta
      end
    end

    private

    def id(resource)
      value = resource && resource['id']
      raise Erro, 'ID de recurso inválido.' unless value.is_a?(String) && value.match?(/\A[A-Za-z0-9-]+\z/)
      value
    end

    def groups
      @client.list("/v1/apps/#{id(@app)}/betaGroups", 'fields[betaGroups]'=>'name,isInternalGroup,hasAccessToAllBuilds')
    end

    def members(group)
      @client.list("/v1/betaGroups/#{id(group)}/betaTesters", 'fields[betaTesters]'=>'email')
    end

    def infos
      @client.list("/v1/apps/#{id(@app)}/appInfos", 'fields[appInfos]'=>'appStoreState,appStoreAgeRating,brazilAgeRating')
    end

    def declaration(info)
      @client.request('GET', "/v1/appInfos/#{id(info)}/ageRatingDeclaration")['data']
    end

    def show_declaration(label, resource)
      # Não registra atributos alheios ao questionário nem URLs vindas da API.
      attrs = resource.fetch('attributes').select { |k, _| (ITENS_NAO + ITENS_NENHUM + %w[userGeneratedContent ageAssurance ageRatingOverride ageRatingOverrideV2 kidsAgeBand]).include?(k) }
      @log.info("#{label}: #{JSON.generate(attrs)}")
    end

    def show_info(info)
      @log.info("AppInfo #{id(info)}: #{JSON.generate(info.fetch('attributes'))}")
    end

    def conferir
      groups.each do |group|
        @log.info("Grupo #{id(group)}: #{group.dig('attributes','name')}; interno=#{group.dig('attributes','isInternalGroup')}; todos_os_builds=#{group.dig('attributes','hasAccessToAllBuilds')}; testadores=#{members(group).size}")
      end
      all = infos
      @log.info('Nenhum appInfo disponível; classificação não encontrada.') if all.empty?
      all.each do |info|
        show_info(info)
        resource = declaration(info)
        if resource
          show_declaration('Classificação atual', resource)
        else
          @log.info('Declaração de classificação ainda não disponível.')
        end
      end
    end

    def grupo_interno
      raise Erro, 'Informe o nome do grupo e os e-mails no disparo.' if @grupo.empty? || @emails.empty?
      raise Erro, 'Há e-mail inválido na entrada; confira a lista do disparo.' unless @emails.all? { |email, _| email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/) }
      matches = groups.select { |g| g.dig('attributes','name') == @grupo }
      raise Erro, 'Mais de um grupo com esse nome; escolha um nome único.' if matches.size > 1
      group = matches.first
      raise Erro, 'O grupo com esse nome é externo; escolha um grupo interno.' if group && group.dig('attributes','isInternalGroup') != true
      users = @client.list('/v1/users', 'fields[users]'=>'username,roles,allAppsVisible')
      existing = group ? members(group).map { |t| id(t) }.to_set : Set.new
      plans, problemas, elegiveis, vistos = [], 0, 0, Set.new
      @emails.each do |email, index|
        if !vistos.add?(email)
          @log.info("Testador #{index}: entrada repetida; já considerado")
          next
        end
        eligible, reason = eligible_user(users, email)
        unless eligible
          problemas += 1
          @log.info("Testador #{index}: #{reason}")
          next
        end
        elegiveis += 1
        testers = @client.list('/v1/betaTesters', 'filter[email]'=>email, 'fields[betaTesters]'=>'email')
        raise Erro, "Testador #{index}: mais de um recurso TestFlight; associação ambígua." if testers.size > 1
        tester = testers.first
        if tester && tester.dig('attributes','email').to_s.downcase != email
          raise Erro, "Testador #{index}: a API retornou outro e-mail; associação recusada."
        end
        if tester && existing.include?(id(tester))
          @log.info("Testador #{index}: já pertence ao grupo")
        else
          plans << [email, index, tester]
          @log.info("Testador #{index}: #{tester ? 'associaria recurso TestFlight existente' : 'criaria recurso TestFlight e associaria'}")
        end
      end
      # Sem nenhum elegível, nem o grupo é criado ou alterado.
      if elegiveis > 0
        group = prepare_group(group)
        plans.each do |email, index, tester|
          next unless @aplicar
          begin
            if tester
              @client.request('POST', "/v1/betaGroups/#{id(group)}/relationships/betaTesters", {'data'=>[{'type'=>'betaTesters','id'=>id(tester)}]})
            else
              @client.request('POST', '/v1/betaTesters', {'data'=>{'type'=>'betaTesters','attributes'=>{'email'=>email},'relationships'=>{'betaGroups'=>{'data'=>[{'type'=>'betaGroups','id'=>id(group)}]}}}})
            end
            @log.info("Testador #{index}: associação aceita pela API")
          rescue ErroAPI => error
            raise unless [400,403,409,422].include?(error.status)
            problemas += 1
            @log.info("Testador #{index}: recusado pela API (HTTP #{error.status})")
          end
        end
        @log.info("Grupo depois: testadores=#{members(group).size}") if @aplicar
      end
      raise Erro, "#{problemas} testador(es) não puderam entrar; confira os índices acima. Nenhum usuário ou papel foi alterado." if problemas > 0
    end

    def eligible_user(users, email)
      user = users.find { |u| u.dig('attributes','username').to_s.downcase == email }
      return [false, 'não consta na equipe (convite pendente ou usuário ausente)'] unless user
      return [false, 'papel não elegível para teste interno'] if (user.dig('attributes','roles').to_a & PAPEIS).empty?
      unless user.dig('attributes','allAppsVisible') == true
        visible = @client.list("/v1/users/#{id(user)}/visibleApps", 'fields[apps]'=>'bundleId')
        return [false, 'sem acesso ao app'] unless visible.any? { |app| id(app) == id(@app) }
      end
      [true, nil]
    end

    def prepare_group(group)
      if group.nil?
        @log.info("Plano: criar grupo interno #{@grupo}, com acesso a todos os builds")
        if @aplicar
          group = @client.request('POST', '/v1/betaGroups', {'data'=>{'type'=>'betaGroups','attributes'=>{'name'=>@grupo,'isInternalGroup'=>true,'hasAccessToAllBuilds'=>true},'relationships'=>{'app'=>{'data'=>{'type'=>'apps','id'=>id(@app)}}}}})['data']
        end
      elsif group.dig('attributes','hasAccessToAllBuilds') != true
        # BetaGroupUpdateRequest não aceita hasAccessToAllBuilds. Não apagar,
        # recriar nem duplicar um grupo existente para contornar essa limitação.
        raise Erro, 'Grupo existente sem acesso a todos os builds: a API só permite definir esse atributo na criação. Nenhum grupo ou testador foi alterado.'
      else
        @log.info('Grupo interno existente já tem acesso a todos os builds')
      end
      if @aplicar && (group.dig('attributes','isInternalGroup') != true || group.dig('attributes','hasAccessToAllBuilds') != true)
        raise Erro, 'A API não confirmou grupo interno com acesso a todos os builds.'
      end
      group
    end

    GRUPO_EXTERNO = 'Testadores Frila'.freeze
    CAMPOS_GRUPO_EXTERNO = 'name,isInternalGroup,publicLinkEnabled,publicLinkLimitEnabled,publicLinkLimit,feedbackEnabled,publicLink'.freeze
    SEGREDOS_BETA = {
      'contactFirstName'=>'BETA_CONTATO_NOME', 'contactLastName'=>'BETA_CONTATO_NOME',
      'contactPhone'=>'BETA_CONTATO_TELEFONE', 'contactEmail'=>'BETA_CONTATO_EMAIL',
      'demoAccountName'=>'BETA_DEMO_USUARIO', 'demoAccountPassword'=>'BETA_DEMO_SENHA'
    }.freeze
    TEXTOS_BETA = {
      'pt-BR'=>{
        'description'=>'Frila conecta estabelecimentos e profissionais autônomos para turnos de trabalho no Distrito Federal. Uso exclusivo para maiores de 18 anos.',
        'whatsNew'=>'Teste entrada, cadastro, publicação de vagas, candidatura, acompanhamento do turno, presença e avaliação. Relate falhas pelo TestFlight.'},
      'en-US'=>{
        'description'=>'Frila connects businesses and independent professionals for work shifts in Brazil’s Federal District. For adults aged 18 and over.',
        'whatsNew'=>'Test sign-in, registration, job posting, applications, shift tracking, attendance and reviews. Report issues through TestFlight.'}
    }.freeze
    NOTAS_BETA = 'Frila-Beta uses the frila-dev test environment. Enter the demo account name supplied in the review credentials on the email screen. Continue to the code screen and enter the six-digit demo code supplied in the password field. No email inbox is required. A professional account applies for shifts; a business account posts jobs. Location is requested for attendance; use the location of the test shift. Accounts and test data must be provisioned in frila-dev before review.'.freeze

    def build_beta
      raise Erro, 'Informe uma versão no formato 0.5.1.' unless @versao.match?(/\A\d+\.\d+\.\d+\z/)
      builds = @client.list('/v1/builds', 'filter[app]'=>id(@app),
        'filter[preReleaseVersion.version]'=>@versao, 'filter[preReleaseVersion.platform]'=>'IOS',
        'filter[processingState]'=>'VALID', 'filter[expired]'=>'false',
        'filter[buildAudienceType]'=>'APP_STORE_ELIGIBLE', 'sort'=>'-uploadedDate',
        'fields[builds]'=>'version,uploadedDate,processingState,expired,buildAudienceType')
      # Mesmo com filtros, confira a resposta antes de qualquer escrita.
      builds = builds.select do |b|
        a = b.fetch('attributes')
        a['processingState'] == 'VALID' && a['expired'] == false && a['buildAudienceType'] == 'APP_STORE_ELIGIBLE'
      end
      build = builds.max_by { |b| b.dig('attributes', 'uploadedDate').to_s }
      unless build
        @log.info("FALTA: build iOS #{@versao} processado (VALID), não expirado e elegível para teste externo")
        return nil
      end
      release = @client.request('GET', "/v1/builds/#{id(build)}/preReleaseVersion")['data']
      unless release && release.dig('attributes', 'version') == @versao && release.dig('attributes', 'platform') == 'IOS'
        raise Erro, 'A versão/plataforma do build retornado diverge da entrada; nenhuma escrita.'
      end
      @log.info("Build selecionado: versão=#{@versao}; número=#{build.dig('attributes', 'version')}; id=#{id(build)}; processamento=VALID")
      @log.info('Proveniência: a API não informa o esquema Xcode; confirme Frila-Beta/frila-dev no workflow TestFlight que enviou esse número de build.')
      build
    end

    def grupo_externo
      raise Erro, 'Limite de testadores deve ser um inteiro de 1 a 10000.' unless @limite.to_s.match?(/\A[1-9]\d*\z/) && (1..10000).cover?(@limite.to_i)
      all = @client.list("/v1/apps/#{id(@app)}/betaGroups", 'fields[betaGroups]'=>CAMPOS_GRUPO_EXTERNO)
      matches = all.select { |g| g.dig('attributes', 'name') == GRUPO_EXTERNO }
      raise Erro, 'Mais de um grupo Testadores Frila; associação ambígua.' if matches.size > 1
      group = matches.first
      raise Erro, 'Testadores Frila é interno; recuso alterar ou reutilizar esse grupo.' if group && group.dig('attributes', 'isInternalGroup') != false
      build = build_beta
      unless build
        @log.info('publicLink: indisponível; falta build elegível')
        raise Erro, 'Não há build elegível; nenhuma escrita.' if @aplicar
        return
      end
      attrs = {'publicLinkEnabled'=>true, 'publicLinkLimitEnabled'=>true, 'publicLinkLimit'=>@limite.to_i, 'feedbackEnabled'=>true}
      changes = group ? attrs.reject { |k, v| group.fetch('attributes')[k] == v } : attrs
      associated = group ? @client.list("/v1/betaGroups/#{id(group)}/builds", 'fields[builds]'=>'version').any? { |b| id(b) == id(build) } : false
      @log.info("Plano: #{group ? 'reutilizar' : 'criar'} grupo externo Testadores Frila; publicLinkEnabled=true; publicLinkLimitEnabled=true; publicLinkLimit=#{@limite}; feedbackEnabled=true")
      @log.info("Plano: #{changes.empty? ? 'configuração já confere' : 'preparar configuração do grupo'}; #{associated ? 'build já associado' : 'associar build selecionado'}")
      if @aplicar
        if group.nil?
          group = @client.request('POST', '/v1/betaGroups', {'data'=>{'type'=>'betaGroups',
            'attributes'=>attrs.merge('name'=>GRUPO_EXTERNO, 'isInternalGroup'=>false),
            'relationships'=>{'app'=>{'data'=>{'type'=>'apps', 'id'=>id(@app)}}}}})['data']
        elsif !changes.empty?
          @client.request('PATCH', "/v1/betaGroups/#{id(group)}", {'data'=>{'type'=>'betaGroups', 'id'=>id(group), 'attributes'=>changes}})
        end
        unless associated
          @client.request('POST', "/v1/betaGroups/#{id(group)}/relationships/builds", {'data'=>[{'type'=>'builds', 'id'=>id(build)}]})
        end
        group = @client.request('GET', "/v1/betaGroups/#{id(group)}")['data']
        unless group && group.dig('attributes', 'isInternalGroup') == false && attrs.all? { |k,v| group.dig('attributes',k) == v }
          raise Erro, 'A API não confirmou a configuração do grupo externo.'
        end
        unless @client.list("/v1/betaGroups/#{id(group)}/builds", 'fields[builds]'=>'version').any? { |b| id(b) == id(build) }
          raise Erro, 'A API não confirmou o build no grupo externo.'
        end
      end
      link = group && group.dig('attributes', 'publicLink')
      if link && !link.match?(/\Ahttps:\/\/testflight\.apple\.com\/join\/[A-Za-z0-9]+\z/)
        raise Erro, 'publicLink retornado pela API inválido; não será impresso.'
      end
      @log.info("publicLink: #{link || 'indisponível no plano; será lido da API após aplicar=true'}")
      @log.info('Distribuição externa depende também da aprovação da Beta App Review.')
      raise Erro, 'A API ainda não forneceu publicLink.' if @aplicar && !link
    end

    def revisao_beta
      detail = @client.request('GET', "/v1/apps/#{id(@app)}/betaAppReviewDetail")['data']
      raise Erro, 'betaAppReviewDetails indisponível; nenhuma escrita.' unless detail
      atual = detail.fetch('attributes')
      # Nunca registrar valores de contato, credenciais ou notas retornados pela API.
      atual.values.grep(String).each { |value| @log.mask(value) }
      missing_secrets = SEGREDOS_BETA.values.uniq.select { |name| @beta_segredos[name].to_s.strip.empty? }
      SEGREDOS_BETA.each do |field, secret|
        @log.info("#{atual[field].to_s.strip.empty? ? 'FALTA' : 'OK'}: betaAppReviewDetails.#{field}; segredo #{secret}=#{missing_secrets.include?(secret) ? 'ausente' : 'presente'}")
      end
      missing_secrets.each { |name| @log.info("FALTA: segredo GitHub #{name}") }
      @log.info("#{atual['notes'].to_s.strip.empty? ? 'FALTA' : 'OK'}: betaAppReviewDetails.notes")
      @log.info("#{atual['demoAccountRequired'] == true ? 'OK' : 'FALTA'}: betaAppReviewDetails.demoAccountRequired=true")
      build = build_beta
      plans = []
      app_locales = @client.list("/v1/apps/#{id(@app)}/betaAppLocalizations")
      build_locales = build ? @client.list("/v1/builds/#{id(build)}/betaBuildLocalizations") : []
      TEXTOS_BETA.each do |locale, texts|
        plans << plano_localizacao('betaAppLocalizations', app_locales, locale,
          {'description'=>texts['description'], 'feedbackEmail'=>'suportefrila@gmail.com'}, 'app', @app)
        if build
          plans << plano_localizacao('betaBuildLocalizations', build_locales, locale,
            {'whatsNew'=>texts['whatsNew']}, 'build', build)
        else
          @log.info("FALTA: betaBuildLocalizations.#{locale}.whatsNew; depende de build elegível")
        end
      end
      submission = build ? submissao_beta(build) : nil
      state = submission && submission.dig('attributes', 'betaReviewState')
      raise Erro, 'Estado de revisão beta desconhecido.' if state && !%w[WAITING_FOR_REVIEW IN_REVIEW APPROVED REJECTED].include?(state)
      @log.info("Revisão beta: #{state || 'sem submissão'}")
      @log.info('FALTA: confirmar contas, código fixo e dados de teste no frila-dev; provisionamento não é provado pela API da Apple')
      @log.info('Plano: preencher metadados pendentes; submeter build somente com aplicar=true e pré-requisitos completos')
      return unless @aplicar
      raise Erro, 'Faltam segredos GitHub beta; nenhuma escrita.' unless missing_secrets.empty?
      raise Erro, 'Falta build elegível; nenhuma escrita.' unless build
      raise Erro, 'Revisão rejeitada: resolva o motivo com o responsável antes de nova submissão.' if state == 'REJECTED'
      nome = @beta_segredos.fetch('BETA_CONTATO_NOME').strip.split(/\s+/, 2)
      raise Erro, 'BETA_CONTATO_NOME precisa conter nome e sobrenome; nenhuma escrita.' unless nome.size == 2
      usuario = @beta_segredos.fetch('BETA_DEMO_USUARIO').strip.downcase
      unless %w[revisao-profissional@frila.app revisao-contratante@frila.app].include?(usuario) && @beta_segredos.fetch('BETA_DEMO_SENHA').match?(/\A[0-9]{6}\z/)
        raise Erro, 'Credenciais devem corresponder ao fluxo de demonstração implementado (conta de revisão e código de seis dígitos); nenhuma escrita.'
      end
      attrs = SEGREDOS_BETA.transform_values { |secret| @beta_segredos.fetch(secret) }
      attrs['contactFirstName'], attrs['contactLastName'] = nome
      attrs['notes'] = NOTAS_BETA if atual['notes'].to_s.strip.empty?
      attrs['demoAccountRequired'] = true
      changes = attrs.reject { |k,v| atual[k] == v }
      unless changes.empty?
        @client.request('PATCH', "/v1/betaAppReviewDetails/#{id(detail)}", {'data'=>{'type'=>'betaAppReviewDetails', 'id'=>id(detail), 'attributes'=>changes}})
      end
      plans.each { |plan| @client.request(*plan) if plan }
      if submission
        @log.info('Submissão existente; não duplicada')
      else
        @client.request('POST', '/v1/betaAppReviewSubmissions', {'data'=>{'type'=>'betaAppReviewSubmissions',
          'relationships'=>{'build'=>{'data'=>{'type'=>'builds', 'id'=>id(build)}}}}})
        @log.info('Submissão beta aceita pela API; aguarde a revisão da Apple')
      end
    end

    def submissao_beta(build)
      @client.request('GET', "/v1/builds/#{id(build)}/betaAppReviewSubmission")['data']
    rescue ErroAPI => error
      # A relação singular pode responder 404 antes da primeira submissão.
      raise unless error.status == 404
      nil
    end

    def plano_localizacao(type, resources, locale, attrs, relationship, parent)
      matches = resources.select { |r| r.dig('attributes', 'locale') == locale }
      raise Erro, "Localização #{type}.#{locale} duplicada; nenhuma escrita." if matches.size > 1
      resource = matches.first
      changes = attrs.reject do |field, expected|
        value = resource && resource.dig('attributes', field)
        # Descrição e o que testar existentes são preservados; feedback é o endereço solicitado.
        ok = field == 'feedbackEmail' ? value == expected : !value.to_s.strip.empty?
        @log.info("#{ok ? 'OK' : 'FALTA'}: #{type}.#{locale}.#{field}")
        ok
      end
      return nil if changes.empty?
      data = {'type'=>type, 'attributes'=>changes}
      if resource
        data['id'] = id(resource)
        ['PATCH', "/v1/#{type}/#{id(resource)}", {'data'=>data}]
      else
        data['attributes']['locale'] = locale
        data['relationships'] = {relationship=>{'data'=>{'type'=>relationship == 'app' ? 'apps' : 'builds', 'id'=>id(parent)}}}
        ['POST', "/v1/#{type}", {'data'=>data}]
      end
    end

    def classificacao
      editable = infos.select { |i| i.dig('attributes','appStoreState') == 'PREPARE_FOR_SUBMISSION' }
      raise Erro, 'É necessário um único appInfo em PREPARE_FOR_SUBMISSION; nenhuma versão foi criada.' unless editable.size == 1
      info = editable.first
      show_info(info)
      before = declaration(info)
      raise Erro, 'Declaração não disponível nesse appInfo; nenhuma versão foi criada.' unless before
      id(before)
      show_declaration('Antes', before)
      attrs = ITENS_NAO.each_with_object({}) { |item, a| a[item] = false }
      ITENS_NENHUM.each { |item| attrs[item] = 'NONE' }
      attrs.merge!('userGeneratedContent'=>true,'ageAssurance'=>@idade,'ageRatingOverrideV2'=>'EIGHTEEN_PLUS','kidsAgeBand'=>nil)
      @log.info("Plano: #{JSON.generate(attrs)}")
      @log.info('Confirmação pessoal de ausência de referências a álcool: pendente') unless @alcool
      return unless @aplicar
      raise Erro, 'Para gravar NONE em álcool, confirme pessoalmente e marque sem_referencias_alcool no disparo (arquivo de passos, item 5).' unless @alcool
      changes = attrs.reject { |k, v| before.fetch('attributes').key?(k) && before['attributes'][k] == v }
      unless changes.empty?
        @client.request('PATCH', "/v1/ageRatingDeclarations/#{id(before)}", {'data'=>{'type'=>'ageRatingDeclarations','id'=>id(before),'attributes'=>changes}})
      end
      after = declaration(info)
      show_declaration('Depois', after)
      raise Erro, 'A declaração relida diverge das respostas planejadas.' unless attrs.all? { |k, v| after.fetch('attributes').key?(k) && after['attributes'][k] == v }
      # A classificação calculada é lida, não presumida a partir do PATCH.
      infos.select { |i| id(i) == id(info) }.each { |i| show_info(i) }
      @log.info('Override EIGHTEEN_PLUS confirmado. Apresentação em sistemas anteriores ao iOS 26: não encontrada nesta resposta da API; conferir separadamente.')
    end
  end

  def self.boolean(env, name, default = 'false')
    value = env.fetch(name, default)
    raise Erro, "#{name} deve ser true ou false." unless %w[true false].include?(value)
    value == 'true'
  end

  def self.entradas(env, event_reader: ->(path) { File.read(path) })
    values = env.to_h.dup
    if env['GITHUB_ACTIONS'] == 'true' && env['GITHUB_EVENT_PATH']
      # Não passe e-mails por env: no YAML: o runner imprime env antes do script.
      # O payload do evento já é fornecido pelo GitHub; nada é copiado ou publicado.
      inputs = JSON.parse(event_reader.call(env['GITHUB_EVENT_PATH'])).fetch('inputs', {})
      {'acao'=>'ASC_ACAO','aplicar'=>'ASC_APLICAR','testadores'=>'ASC_TESTADORES',
        'grupo'=>'ASC_GRUPO','verificacao_idade'=>'ASC_VERIFICACAO_IDADE',
        'sem_referencias_alcool'=>'ASC_SEM_REFERENCIAS_ALCOOL',
        'versao'=>'ASC_VERSAO', 'limite_testadores'=>'ASC_LIMITE_TESTADORES'}.each do |input, name|
        values[name] = inputs[input].to_s if inputs.key?(input)
      end
    end
    values
  rescue JSON::ParserError, IOError, SystemCallError
    raise Erro, 'Não foi possível ler as entradas do evento do GitHub.'
  end

  def self.main(env = ENV, out = $stdout)
    log = Log.new(out, github: env['GITHUB_ACTIONS'] == 'true')
    env = entradas(env)
    env.fetch('ASC_TESTADORES', '').split(/[\s,;]+/).each { |email| log.mask(email); log.mask(email.downcase) }
    token = autenticar(env, log)
    return if env['ASC_VALIDAR_SEGREDOS'] == 'true'
    aplicar = boolean(env, 'ASC_APLICAR')
    Job.new(client: Client.new(token: token, aplicar: aplicar), log: log,
      acao: env.fetch('ASC_ACAO', 'conferir'), aplicar: aplicar,
      emails: env.fetch('ASC_TESTADORES', ''), grupo: env.fetch('ASC_GRUPO', 'Equipe Frila'),
      sem_referencias_alcool: boolean(env, 'ASC_SEM_REFERENCIAS_ALCOOL'),
      verificacao_idade: boolean(env, 'ASC_VERIFICACAO_IDADE', 'true'),
      versao: env.fetch('ASC_VERSAO', '0.5.1'), limite: env.fetch('ASC_LIMITE_TESTADORES', '1000'),
      beta_segredos: Job::SEGREDOS_BETA.values.uniq.to_h { |name| [name, env[name]] }).run
  rescue Erro => error
    log.info("ERRO: #{error.message}")
    raise
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    AppStoreConnect.main
  rescue AppStoreConnect::Erro
    exit 1
  rescue StandardError
    # Sem backtrace: erros inesperados podem trazer argumentos sensíveis.
    $stderr.puts('ERRO: falha inesperada; nenhuma conclusão sobre a API. Confira o script com os testes locais.')
    exit 1
  end
end
