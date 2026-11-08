#!/usr/bin/env ruby
# Testes locais: respostas de exemplo, transporte em memória e assinatura fictícia.
require 'minitest/autorun'
require 'stringio'
require_relative 'app-store-connect'

# Qualquer caminho que escapar do transporte fictício reprova a prova offline.
Net::HTTP.singleton_class.prepend(Module.new do
  def start(*)
    raise 'Teste offline tentou acessar a rede'
  end
end)

class APIDeExemplo
  attr_reader :dados, :chamadas
  attr_accessor :rejeitar_testador, :ignorar_classificacao

  def initialize
    @dados = JSON.parse(File.read(File.join(__dir__, 'FixturesAppStoreConnect/respostas.json')))
    @chamadas = []
  end

  def call(req)
    uri = req.uri
    path = uri.path
    query = URI.decode_www_form(uri.query || '').to_h
    body = req.body ? JSON.parse(req.body) : nil
    @chamadas << [req.method, path, body]
    if rejeitar_testador && req.method == 'POST' && path == '/v1/betaTesters'
      return Struct.new(:code, :body).new('422', JSON.generate(dados['erro']))
    end
    status = 200
    result = nil
    if req.method == 'GET'
      result = case path
      when '/v1/apps' then dados['apps']
      when '/v1/apps/app-1/betaGroups' then dados['betaGroups']
      when '/v1/apps/app-1/appInfos' then dados['appInfos']
      when '/v1/appInfos/info-1/ageRatingDeclaration' then dados['ageRatingDeclaration']
      when '/v1/users' then dados['users']
      when %r{\A/v1/users/([^/]+)/visibleApps\z}
        (dados['visibleApps'][$1] || []).map { |id| {'id'=>id,'type'=>'apps'} }
      when '/v1/betaTesters'
        dados['betaTesters'].select { |t| t['attributes']['email'] == query['filter[email]'] }
      when %r{\A/v1/betaGroups/([^/]+)/betaTesters\z}
        ids = dados['membros'][$1] || []
        dados['betaTesters'].select { |t| ids.include?(t['id']) }
      else raise "GET inesperado: #{path}"
      end
    elsif req.method == 'POST' && path == '/v1/betaGroups'
      result = body['data'].merge('id'=>'grupo-novo')
      dados['betaGroups'] << result
      status = 201
    elsif req.method == 'PATCH' && path.start_with?('/v1/betaGroups/')
      result = dados['betaGroups'].find { |g| g['id'] == body['data']['id'] }
      result['attributes'].merge!(body['data']['attributes'])
    elsif req.method == 'POST' && path == '/v1/betaTesters'
      result = body['data'].merge('id'=>'tester-novo')
      dados['betaTesters'] << result
      group = body['data']['relationships']['betaGroups']['data'][0]['id']
      (dados['membros'][group] ||= []) << result['id']
      status = 201
    elsif req.method == 'POST' && path.end_with?('/relationships/betaTesters')
      group = path.split('/')[3]
      (dados['membros'][group] ||= []).concat(body['data'].map { |t| t['id'] }).uniq!
      status = 204
    elsif req.method == 'PATCH' && path == '/v1/ageRatingDeclarations/idade-1'
      result = dados['ageRatingDeclaration']
      result['attributes'].merge!(body['data']['attributes']) unless ignorar_classificacao
    else
      raise "Chamada inesperada: #{req.method} #{path}"
    end
    payload = {'data'=>result}
    Struct.new(:code, :body).new(status.to_s, status == 204 ? '' : JSON.generate(payload))
  end

  def escritas
    chamadas.reject { |method, _, _| method == 'GET' }
  end
end

class AppStoreConnectTest < Minitest::Test
  def setup
    @api = APIDeExemplo.new
    @saida = StringIO.new
    @log = AppStoreConnect::Log.new(@saida, github: false)
    @client = AppStoreConnect::Client.new(token: -> {'jwt-ficticio'}, transport: @api.method(:call))
  end

  def rodar(acao, aplicar: false, emails: 'primeiro@example.invalid,segundo@example.invalid', alcool: true, idade: true)
    @client = AppStoreConnect::Client.new(token: -> {'jwt-ficticio'}, transport: @api.method(:call), aplicar: aplicar)
    AppStoreConnect::Job.new(client: @client, log: @log, acao: acao, aplicar: aplicar,
      emails: emails, grupo: 'Equipe Frila', sem_referencias_alcool: alcool, verificacao_idade: idade).run
  end

  def test_conferir_so_le_contagens_e_classificacao
    rodar('conferir', aplicar: true)
    assert_empty @api.escritas
    assert_includes @saida.string, 'testadores=1'
    assert_includes @saida.string, 'FOUR_PLUS'
    refute_match(/\S+@\S+/, @saida.string)
  end

  def test_grupo_ensaio_nao_cria_nem_associa
    @api.dados['betaGroups'] = []
    rodar('grupo-interno')
    assert_empty @api.escritas
    assert_includes @saida.string, 'Plano: criar grupo interno'
    assert_includes @saida.string, 'Testador 2: criaria recurso TestFlight e associaria'
  end

  def test_grupo_idempotente_preserva_membros_fora_da_lista
    @api.dados['membros']['grupo-1'] << 'tester-extra'
    rodar('grupo-interno', aplicar: true)
    assert_equal ['POST'], @api.escritas.map(&:first)
    assert_includes @api.dados['membros']['grupo-1'], 'tester-extra'
    quantidade = @api.escritas.size
    rodar('grupo-interno', aplicar: true)
    assert_equal quantidade, @api.escritas.size
    assert_includes @saida.string, 'Testador 2: já pertence ao grupo'
  end

  def test_cria_grupo_interno_com_acesso_a_todos_os_builds
    @api.dados['betaGroups'] = []
    rodar('grupo-interno', aplicar: true)
    grupo = @api.escritas.find { |_, path, _| path == '/v1/betaGroups' }[2]['data']
    assert_equal true, grupo['attributes']['isInternalGroup']
    assert_equal true, grupo['attributes']['hasAccessToAllBuilds']
    assert_equal 'app-1', grupo['relationships']['app']['data']['id']
  end

  def test_grupo_existente_sem_distribuicao_automatica_para_sem_escrever
    @api.dados['betaGroups'][0]['attributes']['hasAccessToAllBuilds'] = false
    assert_raises(AppStoreConnect::Erro) { rodar('grupo-interno', aplicar: true, emails: 'primeiro@example.invalid') }
    assert_empty @api.escritas
    assert_equal false, @api.dados['betaGroups'][0]['attributes']['hasAccessToAllBuilds']
  end

  def test_associa_recurso_testflight_ja_existente
    @api.dados['betaTesters'] << {'id'=>'tester-2','attributes'=>{'email'=>'segundo@example.invalid'}}
    rodar('grupo-interno', aplicar: true)
    assert_equal '/v1/betaGroups/grupo-1/relationships/betaTesters', @api.escritas[0][1]
    assert_includes @api.dados['membros']['grupo-1'], 'tester-2'
  end

  def test_convite_pendente_papel_e_acesso_inadequados_nao_escrevem
    error = assert_raises(AppStoreConnect::Erro) do
      rodar('grupo-interno', aplicar: true, emails: 'pendente@example.invalid,financeiro@example.invalid,sem-acesso@example.invalid')
    end
    assert_includes error.message, '3 testador(es)'
    assert_empty @api.escritas
    assert_includes @saida.string, 'Testador 1: não consta na equipe'
    assert_includes @saida.string, 'Testador 2: papel não elegível'
    assert_includes @saida.string, 'Testador 3: sem acesso ao app'
  end

  def test_rejeicao_da_apple_reporta_indice_sem_email_ou_detail
    @api.rejeitar_testador = true
    assert_raises(AppStoreConnect::Erro) { rodar('grupo-interno', aplicar: true) }
    assert_includes @saida.string, 'Testador 2: recusado pela API (HTTP 422)'
    refute_includes @saida.string, 'segundo@example.invalid'
  end

  def test_grupo_externo_ou_duplicado_nao_e_alterado
    @api.dados['betaGroups'][0]['attributes']['isInternalGroup'] = false
    assert_raises(AppStoreConnect::Erro) { rodar('grupo-interno', aplicar: true) }
    assert_empty @api.escritas
    @api.dados['betaGroups'][0]['attributes']['isInternalGroup'] = true
    @api.dados['betaGroups'] << @api.dados['betaGroups'][0].merge('id'=>'duplicado')
    assert_raises(AppStoreConnect::Erro) { rodar('grupo-interno', aplicar: true) }
    assert_empty @api.escritas
  end

  def test_classificacao_ensaio_e_respostas_18_mais
    rodar('classificacao', alcool: false)
    assert_empty @api.escritas
    assert_includes @saida.string, 'Antes:'
    assert_includes @saida.string, 'Plano:'
    assert_includes @saida.string, 'EIGHTEEN_PLUS'
    refute_includes @saida.string, 'Depois:'
  end

  def test_classificacao_aplica_rele_e_confere_respostas
    rodar('classificacao', aplicar: true)
    attrs = @api.dados['ageRatingDeclaration']['attributes']
    assert_equal true, attrs['userGeneratedContent']
    assert_equal false, attrs['messagingAndChat']
    assert_equal true, attrs['ageAssurance']
    assert_equal 'EIGHTEEN_PLUS', attrs['ageRatingOverrideV2']
    assert_equal 'NONE', attrs['alcoholTobaccoOrDrugUseOrReferences']
    assert_nil attrs['kidsAgeBand']
    assert_includes @saida.string, 'Depois:'
    quantidade = @api.escritas.size
    rodar('classificacao', aplicar: true)
    assert_equal quantidade, @api.escritas.size
  end

  def test_sem_declared_age_range_responde_nao
    rodar('classificacao', aplicar: true, idade: false)
    assert_equal false, @api.dados['ageRatingDeclaration']['attributes']['ageAssurance']
    refute @api.escritas[0][2]['data']['attributes'].key?('ageAssurance')
  end

  def test_confirmacao_de_alcool_e_app_info_editavel_obrigatorios_para_gravar
    assert_raises(AppStoreConnect::Erro) { rodar('classificacao', aplicar: true, alcool: false) }
    assert_empty @api.escritas
    @api.dados['appInfos'][0]['attributes']['appStoreState'] = 'READY_FOR_SALE'
    assert_raises(AppStoreConnect::Erro) { rodar('classificacao', aplicar: true) }
    assert_empty @api.escritas
    @api.dados['appInfos'] = []
    assert_raises(AppStoreConnect::Erro) { rodar('classificacao', aplicar: true) }
    assert_empty @api.escritas
  end

  def test_resposta_depois_divergente_falha
    @api.ignorar_classificacao = true
    assert_raises(AppStoreConnect::Erro) { rodar('classificacao', aplicar: true) }
  end

  def test_aplicar_falso_tambem_bloqueia_escrita_no_cliente
    cliente = AppStoreConnect::Client.new(token: -> {'falso'}, transport: @api.method(:call), aplicar: false)
    assert_raises(AppStoreConnect::Erro) { cliente.request('POST', '/v1/betaGroups', {}) }
    assert_empty @api.chamadas
  end

  def test_paginacao_e_recusa_link_fora_da_apple
    respostas = [ {'data'=>[{'id'=>'1'}],'links'=>{'next'=>'https://api.appstoreconnect.apple.com/v1/apps?cursor=2'}}, {'data'=>[{'id'=>'2'}]} ]
    transporte = ->(_) { Struct.new(:code, :body).new('200', JSON.generate(respostas.shift)) }
    cliente = AppStoreConnect::Client.new(token: -> {'falso'}, transport: transporte)
    assert_equal ['1','2'], cliente.list('/v1/apps').map { |d| d['id'] }
    assert_raises(AppStoreConnect::Erro) { cliente.request('GET','https://outro.example.invalid/v1/apps') }
  end

  def test_segredos_ausentes_falham_antes_de_ler_chave
    leitor = ->(_) { flunk 'Não deve tentar ler chave' }
    error = assert_raises(AppStoreConnect::Erro) { AppStoreConnect.autenticar({}, @log, key_reader: leitor) }
    %w[APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_API_ISSUER_ID APP_STORE_CONNECT_API_KEY_P8].each { |name| assert_includes error.message, name }
  end

  def test_mascaramento_multilinha_e_jwt_sem_chave_real
    ambiente = {'ASC_KEY_ID'=>'id-ficticio','ASC_ISSUER_ID'=>'issuer-ficticio','ASC_KEY_P8'=>"linha-secreta-1\nlinha-secreta-2"}
    chave = Object.new
    def chave.private?; true; end
    def chave.group; Struct.new(:curve_name).new('prime256v1'); end
    def chave.dsa_sign_asn1(_); OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(1),OpenSSL::ASN1::Integer.new(2)]).to_der; end
    token = AppStoreConnect.autenticar(ambiente, @log, key_reader: ->(_) { chave }).call
    @log.mask('primeiro@example.invalid')
    @log.info("#{token} #{ambiente.values.join(' ')} primeiro@example.invalid desconhecido@example.invalid")
    refute_includes @saida.string, token
    ambiente.values.each { |valor| refute_includes @saida.string, valor }
    refute_match(/\S+@\S+/, @saida.string)
    header, payload, signature = token.split('.')
    assert_equal 'ES256', JSON.parse(Base64.urlsafe_decode64(header))['alg']
    claims = JSON.parse(Base64.urlsafe_decode64(payload))
    assert_equal 'appstoreconnect-v1', claims['aud']
    assert_equal 600, claims['exp'] - claims['iat']
    assert_equal 64, Base64.urlsafe_decode64(signature).bytesize
    out = StringIO.new
    log = AppStoreConnect::Log.new(out, github: true)
    log.mask("segredo\nmultilinha%")
    assert_includes out.string, '::add-mask::segredo%0Amultilinha%25'
    log.info("segredo\nmultilinha%")
    visivel = out.string.lines.reject { |line| line.start_with?('::add-mask::') }.join
    refute_includes visivel, 'segredo'
  end

  def test_entradas_lidas_do_evento_sem_interpolacao_no_workflow
    json = JSON.generate({'inputs'=>{'testadores'=>'privado@example.invalid','aplicar'=>false,'acao'=>'grupo-interno'}})
    env = AppStoreConnect.entradas({'GITHUB_ACTIONS'=>'true','GITHUB_EVENT_PATH'=>'evento-ficticio'}, event_reader: ->(_) { json })
    assert_equal 'privado@example.invalid', env['ASC_TESTADORES']
    assert_equal 'false', env['ASC_APLICAR']
    yaml = File.read(File.join(__dir__, '../../.github/workflows/app-store-connect.yml'))
    refute_match(/\$\{\{\s*inputs\./, yaml)
    refute_includes yaml, 'ASC_TESTADORES:'
  end

  def test_booleano_invalido_nao_vira_autorizacao
    assert_raises(AppStoreConnect::Erro) { AppStoreConnect.boolean({'ASC_APLICAR'=>'sim'}, 'ASC_APLICAR') }
    assert_equal false, AppStoreConnect.boolean({}, 'ASC_APLICAR')
  end

  def test_entrada_repetida_nao_duplica_associacao_e_preserva_indices
    rodar('grupo-interno', aplicar: true, emails: 'segundo@example.invalid,SEGUNDO@example.invalid,pendente@example.invalid')
    flunk 'Convite pendente deve sinalizar entrega parcial'
  rescue AppStoreConnect::Erro => error
    assert_includes error.message, '1 testador(es)'
    assert_equal 1, @api.escritas.size
    assert_includes @saida.string, 'Testador 2: entrada repetida'
    assert_includes @saida.string, 'Testador 3: não consta na equipe'
  end

  def test_ensaio_com_grupo_existente_nao_associa
    rodar('grupo-interno')
    assert_empty @api.escritas
    assert_equal ['tester-1'], @api.dados['membros']['grupo-1']
  end
end

# Cenários beta isolados: nenhuma credencial ou resposta real é usada.
class APIBetaDeExemplo < APIDeExemplo
  attr_accessor :builds, :release, :detail, :app_locales, :build_locales, :submission, :submission_status
  attr_reader :build_query

  def initialize
    super
    @builds = [
      {'type'=>'builds', 'id'=>'build-antigo', 'attributes'=>{'version'=>'101', 'uploadedDate'=>'2026-10-20T00:00:00Z', 'processingState'=>'VALID', 'expired'=>false, 'buildAudienceType'=>'APP_STORE_ELIGIBLE'}},
      {'type'=>'builds', 'id'=>'build-novo', 'attributes'=>{'version'=>'102', 'uploadedDate'=>'2026-10-22T00:00:00Z', 'processingState'=>'VALID', 'expired'=>false, 'buildAudienceType'=>'APP_STORE_ELIGIBLE'}},
      {'type'=>'builds', 'id'=>'build-processando', 'attributes'=>{'version'=>'103', 'uploadedDate'=>'2026-10-23T00:00:00Z', 'processingState'=>'PROCESSING', 'expired'=>false, 'buildAudienceType'=>'APP_STORE_ELIGIBLE'}}]
    @release = {'id'=>'release-1', 'attributes'=>{'version'=>'0.5.1', 'platform'=>'IOS'}}
    @detail = {'type'=>'betaAppReviewDetails', 'id'=>'review-1', 'attributes'=>{}}
    @app_locales, @build_locales, @associados = [], [], {}
  end

  def call(req)
    path, method = req.uri.path, req.method
    body = req.body ? JSON.parse(req.body) : nil
    if method == 'GET' && path.end_with?('/betaAppReviewSubmission') && submission_status
      return Struct.new(:code, :body).new(submission_status.to_s, '{}')
    end
    @build_query = URI.decode_www_form(req.uri.query || '').to_h if path == '/v1/builds'
    handled = true
    result = if method == 'GET'
      case path
      when '/v1/builds' then builds
      when %r{\A/v1/builds/[^/]+/preReleaseVersion\z} then release
      when '/v1/apps/app-1/betaAppReviewDetail' then detail
      when '/v1/apps/app-1/betaAppLocalizations' then app_locales
      when %r{\A/v1/builds/[^/]+/betaBuildLocalizations\z} then build_locales
      when %r{\A/v1/builds/[^/]+/betaAppReviewSubmission\z} then submission
      when %r{\A/v1/betaGroups/([^/]+)/builds\z} then (@associados[$1] || []).map { |b| {'id'=>b, 'type'=>'builds'} }
      when %r{\A/v1/betaGroups/([^/]+)\z} then dados['betaGroups'].find { |g| g['id'] == $1 }
      else handled = false
      end
    elsif method == 'POST' && path.end_with?('/relationships/builds')
      group = path.split('/')[3]
      (@associados[group] ||= []).concat(body['data'].map { |b| b['id'] }).uniq!
      nil
    elsif method == 'PATCH' && path == '/v1/betaAppReviewDetails/review-1'
      detail['attributes'].merge!(body['data']['attributes'])
      detail
    elsif method == 'POST' && %w[/v1/betaAppLocalizations /v1/betaBuildLocalizations].include?(path)
      collection = path == '/v1/betaAppLocalizations' ? app_locales : build_locales
      result = body['data'].merge('id'=>"locale-#{collection.size}")
      collection << result
      result
    elsif method == 'PATCH' && path.match?(%r{\A/v1/beta(?:App|Build)Localizations/})
      collection = path.include?('betaAppLocalizations') ? app_locales : build_locales
      result = collection.find { |r| r['id'] == body['data']['id'] }
      result['attributes'].merge!(body['data']['attributes'])
      result
    elsif method == 'POST' && path == '/v1/betaAppReviewSubmissions'
      self.submission = body['data'].merge('id'=>'submission-1', 'attributes'=>{'betaReviewState'=>'WAITING_FOR_REVIEW'})
    else
      handled = false
    end
    return super unless handled
    chamadas << [method, path, body]
    Struct.new(:code, :body).new('200', JSON.generate({'data'=>result}))
  end
end

class BetaAppStoreConnectTest < Minitest::Test
  def setup
    @api = APIBetaDeExemplo.new
    @out = StringIO.new
    @log = AppStoreConnect::Log.new(@out, github: false)
    @secrets = {'BETA_CONTATO_NOME'=>'Pessoa Ficticia', 'BETA_CONTATO_TELEFONE'=>'+5500000000000',
      'BETA_CONTATO_EMAIL'=>'contato@example.invalid', 'BETA_DEMO_USUARIO'=>'revisao-profissional@frila.app', 'BETA_DEMO_SENHA'=>'123456'}
  end

  def run_beta(action, apply: false, secrets: @secrets, version: '0.5.1', limit: '1000')
    client = AppStoreConnect::Client.new(token: -> { 'jwt-falso' }, aplicar: apply, transport: @api.method(:call))
    AppStoreConnect::Job.new(client: client, log: @log, acao: action, aplicar: apply, emails: '', grupo: 'IGNORADO',
      sem_referencias_alcool: false, verificacao_idade: true, versao: version, limite: limit, beta_segredos: secrets).run
  end

  def make_external
    @api.dados['betaGroups'] << {'id'=>'externo-1', 'type'=>'betaGroups', 'attributes'=>{
      'name'=>'Testadores Frila', 'isInternalGroup'=>false, 'publicLink'=>'https://testflight.apple.com/join/Exemplo12'}}
  end

  def test_plano_externo_nao_escreve_e_seleciona_mais_recente_processado
    run_beta('grupo-externo')
    assert_empty @api.escritas
    assert_includes @out.string, 'Plano: criar grupo externo Testadores Frila'
    assert_includes @out.string, 'publicLinkLimit=1000'
    assert_includes @out.string, 'id=build-novo'
    refute_includes @out.string, 'id=build-processando'
    assert_equal '0.5.1', @api.build_query['filter[preReleaseVersion.version]']
    assert_equal 'IOS', @api.build_query['filter[preReleaseVersion.platform]']
    assert_equal 'VALID', @api.build_query['filter[processingState]']
    assert_equal 'false', @api.build_query['filter[expired]']
    assert_equal 'APP_STORE_ELIGIBLE', @api.build_query['filter[buildAudienceType]']
    assert_equal '-uploadedDate', @api.build_query['sort']
  end

  def test_grupo_externo_cria_associa_e_reutiliza_sem_duplicacao
    run_beta('grupo-externo', apply: true)
    flunk 'Fixture sem publicLink deve exigir confirmação'
  rescue AppStoreConnect::Erro => e
    assert_includes e.message, 'publicLink'
    group = @api.dados['betaGroups'].last
    assert_equal false, group['attributes']['isInternalGroup']
    assert_equal 'Testadores Frila', group['attributes']['name']
    assert_equal 1000, group['attributes']['publicLinkLimit']
    group['attributes']['publicLink'] = 'https://testflight.apple.com/join/Exemplo12'
    before = @api.escritas.size
    run_beta('grupo-externo', apply: true)
    run_beta('grupo-externo', apply: true)
    assert_equal before, @api.escritas.size
    assert_includes @out.string, 'publicLink: https://testflight.apple.com/join/Exemplo12'
    assert_equal ['build-novo'], @api.escritas.find { |_, path, _| path.end_with?('/relationships/builds') }[2]['data'].map { |b| b['id'] }
  end

  def test_grupo_existente_atualiza_limite_feedback_e_link_sem_recriar
    make_external
    run_beta('grupo-externo', apply: true, limit: '2000')
    assert_equal ['PATCH', 'POST'], @api.escritas.map(&:first)
    assert_equal 2000, @api.dados['betaGroups'].last['attributes']['publicLinkLimit']
    before = @api.escritas.size
    run_beta('grupo-externo', apply: true, limit: '2000')
    assert_equal before, @api.escritas.size
  end

  def test_recusa_interno_homonimo_e_grupo_duplicado_sem_escrita
    make_external
    @api.dados['betaGroups'].last['attributes']['isInternalGroup'] = true
    [false, true].each do |apply|
      e = assert_raises(AppStoreConnect::Erro) { run_beta('grupo-externo', apply: apply) }
      assert_includes e.message, 'interno'
    end
    @api.dados['betaGroups'].last['attributes']['isInternalGroup'] = false
    make_external
    assert_raises(AppStoreConnect::Erro) { run_beta('grupo-externo', apply: true) }
    assert_empty @api.escritas
  end

  def test_falta_build_ou_diverge_versao_nao_escreve
    @api.builds.each { |b| b['attributes']['processingState'] = 'PROCESSING' }
    run_beta('grupo-externo')
    assert_includes @out.string, 'FALTA: build iOS 0.5.1'
    assert_raises(AppStoreConnect::Erro) { run_beta('grupo-externo', apply: true) }
    run_beta('revisao-beta', secrets: {})
    assert_includes @out.string, 'betaBuildLocalizations.pt-BR.whatsNew'
    assert_empty @api.escritas
    setup
    @api.release['attributes']['version'] = '0.5.0'
    assert_raises(AppStoreConnect::Erro) { run_beta('grupo-externo', apply: true) }
    assert_empty @api.escritas
  end

  def test_limite_versao_e_link_invalidos
    %w[0 10001 -1 1.5 abc].each { |limit| assert_raises(AppStoreConnect::Erro) { run_beta('grupo-externo', apply: true, limit: limit) } }
    assert_raises(AppStoreConnect::Erro) { run_beta('grupo-externo', version: 'incorreta') }
    make_external
    @api.dados['betaGroups'].last['attributes']['publicLink'] = 'https://outro.invalid/privado'
    assert_raises(AppStoreConnect::Erro) { run_beta('grupo-externo') }
    refute_includes @out.string, 'outro.invalid'
    assert_empty @api.escritas
  end

  def test_revisao_plano_lista_campo_a_campo_sem_dado_pessoal
    @api.detail['attributes'] = {'contactFirstName'=>'Nome Privado', 'contactLastName'=>'Sobrenome Privado',
      'notes'=>'Notas privadas com telefone e credencial', 'contactPhone'=>'+5511111111111', 'contactEmail'=>'pessoa@example.invalid'}
    run_beta('revisao-beta', secrets: {})
    assert_empty @api.escritas
    %w[BETA_CONTATO_NOME BETA_CONTATO_TELEFONE BETA_CONTATO_EMAIL BETA_DEMO_USUARIO BETA_DEMO_SENHA].each { |name| assert_includes @out.string, "FALTA: segredo GitHub #{name}" }
    %w[pt-BR en-US].each do |locale|
      %w[description feedbackEmail].each { |field| assert_includes @out.string, "FALTA: betaAppLocalizations.#{locale}.#{field}" }
      assert_includes @out.string, "FALTA: betaBuildLocalizations.#{locale}.whatsNew"
    end
    @api.detail['attributes'].values.each { |value| refute_includes @out.string, value }
    refute_match(/\S+@\S+/, @out.string)
  end

  def test_revisao_preenche_e_submete_uma_vez_sem_vazar_segredos
    run_beta('revisao-beta', apply: true)
    attrs = @api.detail['attributes']
    assert_equal 'Pessoa', attrs['contactFirstName']
    assert_equal 'Ficticia', attrs['contactLastName']
    assert_equal true, attrs['demoAccountRequired']
    assert_equal '123456', attrs['demoAccountPassword']
    assert_equal %w[en-US pt-BR], @api.app_locales.map { |r| r['attributes']['locale'] }.sort
    assert @api.app_locales.all? { |r| r['attributes']['feedbackEmail'] == 'suporte@frilabr.com' }
    assert_equal 2, @api.build_locales.size
    submission = @api.escritas.last
    assert_equal '/v1/betaAppReviewSubmissions', submission[1]
    assert_equal 'build-novo', submission[2]['data']['relationships']['build']['data']['id']
    before = @api.escritas.size
    run_beta('revisao-beta', apply: true)
    assert_equal before, @api.escritas.size
    @secrets.values.each { |value| refute_includes @out.string, value }
    refute_includes @out.string, 'Ficticia'
    refute_match(/\S+@\S+/, @out.string)
  end

  def test_revisao_sem_segredos_ou_com_credencial_incompativel_nao_escreve
    [{}, @secrets.merge('BETA_CONTATO_NOME'=>'Pessoa'), @secrets.merge('BETA_DEMO_SENHA'=>'senha'),
      @secrets.merge('BETA_DEMO_USUARIO'=>'outro@example.invalid')].each do |secrets|
      assert_raises(AppStoreConnect::Erro) { run_beta('revisao-beta', apply: true, secrets: secrets) }
    end
    assert_empty @api.escritas
  end

  # As contas de revisão em frilabr.com e as antigas em frila.app são aceitas; outra conta, não.
  def test_revisao_aceita_as_quatro_contas_de_demonstracao
    %w[revisao-contratante@frilabr.com revisao-profissional@frilabr.com
       Revisao-Contratante@FrilaBR.com revisao-contratante@frila.app].each do |usuario|
      @api = APIBetaDeExemplo.new
      run_beta('revisao-beta', apply: true, secrets: @secrets.merge('BETA_DEMO_USUARIO'=>usuario))
      assert_equal usuario, @api.detail['attributes']['demoAccountName']
      assert @api.escritas.any? { |_, path, _| path == '/v1/betaAppReviewSubmissions' }, "submete com #{usuario}"
    end
    @api = APIBetaDeExemplo.new
    assert_raises(AppStoreConnect::Erro) do
      run_beta('revisao-beta', apply: true, secrets: @secrets.merge('BETA_DEMO_USUARIO'=>'outro@frilabr.com'))
    end
    assert_empty @api.escritas
    refute_match(/\S+@\S+/, @out.string)
  end

  def test_revisao_existente_nao_duplica_e_preserva_textos
    @api.submission = {'id'=>'review-existing', 'attributes'=>{'betaReviewState'=>'APPROVED'}}
    @api.app_locales = [{'id'=>'locale-existing', 'attributes'=>{'locale'=>'pt-BR', 'description'=>'Descrição existente', 'feedbackEmail'=>'antigo@example.invalid'}}]
    @api.detail['attributes']['notes'] = 'Instruções existentes'
    run_beta('revisao-beta', apply: true)
    refute @api.escritas.any? { |_, path, _| path == '/v1/betaAppReviewSubmissions' }
    assert_equal 'Descrição existente', @api.app_locales.first['attributes']['description']
    assert_equal 'Instruções existentes', @api.detail['attributes']['notes']
    assert_equal 'suporte@frilabr.com', @api.app_locales.first['attributes']['feedbackEmail']
    @api.submission['attributes']['betaReviewState'] = 'REJECTED'
    before = @api.escritas.size
    assert_raises(AppStoreConnect::Erro) { run_beta('revisao-beta', apply: true) }
    assert_equal before, @api.escritas.size
  end

  def test_submissao_ausente_404_e_falha_de_permissao_nao_confundidas
    @api.submission_status = 404
    run_beta('revisao-beta')
    assert_includes @out.string, 'Revisão beta: sem submissão'
    assert_empty @api.escritas
    @api.submission_status = 403
    assert_raises(AppStoreConnect::ErroAPI) { run_beta('revisao-beta', apply: true) }
    assert_empty @api.escritas
  end

  def test_evento_somente_entradas_publicas_e_segredos_fora_dos_inputs
    json = JSON.generate({'inputs'=>{'acao'=>'grupo-externo', 'versao'=>'0.5.1', 'limite_testadores'=>'500', 'BETA_DEMO_SENHA'=>'ignorado'}})
    env = AppStoreConnect.entradas({'GITHUB_ACTIONS'=>'true','GITHUB_EVENT_PATH'=>'evento-ficticio'}, event_reader: ->(_) { json })
    assert_equal '500', env['ASC_LIMITE_TESTADORES']
    assert_equal '0.5.1', env['ASC_VERSAO']
    refute env.key?('BETA_DEMO_SENHA')
    workflow = File.read(File.join(__dir__, '../../.github/workflows/app-store-connect.yml'))
    inputs = workflow.split('permissions:').first
    AppStoreConnect::Job::SEGREDOS_BETA.values.uniq.each { |name| refute_includes inputs, name }
  end
end

# Ação notas-do-build: grava o rótulo do esquema em "O que testar" do build recém-enviado.
# Tudo em memória: nenhuma chamada real ao App Store Connect, nenhum arquivo real, nenhuma chave.
class NotasDoBuildTest < Minitest::Test
  NUMERO = '20261106.153012'.freeze
  ROTULO_PROD = 'Frila-Prod · frila-prod · LOJA'.freeze
  ROTULO_BETA = 'Frila-Beta · frila-dev'.freeze

  def setup
    @api = APIBetaDeExemplo.new
    @api.builds = [{'type'=>'builds', 'id'=>'build-ci', 'attributes'=>{'version'=>NUMERO, 'uploadedDate'=>'2026-11-06T15:30:12Z',
      'processingState'=>'VALID', 'expired'=>false, 'buildAudienceType'=>'INTERNAL_ONLY'}}]
    @out = StringIO.new
    @log = AppStoreConnect::Log.new(@out, github: false)
    @dormidas = []
    @conteudo = "#{ROTULO_PROD}\n"
  end

  def estado_do_build=(estado)
    @api.builds.first['attributes']['processingState'] = estado
  end

  # espera: 0 consulta uma única vez; com espera 2 e intervalo 1 há até três consultas.
  def run_notas(apply: true, numero: NUMERO, arquivo: 'o-que-testar.txt', versao: '0.5.1', espera: 0, intervalo: 1,
                transporte: nil, leitor: nil, &ao_dormir)
    client = AppStoreConnect::Client.new(token: -> { 'jwt-falso' }, aplicar: apply, transport: transporte || @api.method(:call))
    dormir = lambda do |segundos|
      @dormidas << segundos
      ao_dormir.call if ao_dormir
    end
    AppStoreConnect::Job.new(client: client, log: @log, acao: 'notas-do-build', aplicar: apply, emails: '', grupo: 'IGNORADO',
      sem_referencias_alcool: false, verificacao_idade: true, versao: versao, numero_build: numero, notas_arquivo: arquivo,
      espera: espera, intervalo: intervalo, dormir: dormir, leitor: leitor || ->(_) { @conteudo }).run
  end

  def whats_new(locale)
    @api.build_locales.find { |r| r['attributes']['locale'] == locale }['attributes']['whatsNew']
  end

  def localizacao(locale, texto)
    @api.build_locales << {'type'=>'betaBuildLocalizations', 'id'=>"existente-#{locale}", 'attributes'=>{'locale'=>locale, 'whatsNew'=>texto}}
  end

  def test_plano_nao_escreve_e_localiza_o_build_pelo_numero
    run_notas(apply: false)
    assert_empty @api.escritas
    assert_includes @out.string, 'Plano: gravar o rótulo em 2 localização(ões)'
    assert_includes @out.string, "número=#{NUMERO}"
    assert_equal NUMERO, @api.build_query['filter[version]']
    assert_equal '0.5.1', @api.build_query['filter[preReleaseVersion.version]']
    assert_equal 'IOS', @api.build_query['filter[preReleaseVersion.platform]']
    # Build de ensaio ou de medição é só interno: não filtra por público da loja.
    refute @api.build_query.key?('filter[buildAudienceType]')
  end

  def test_cria_o_texto_com_o_rotulo_na_primeira_linha
    run_notas
    assert_equal 2, @api.escritas.size
    assert(@api.escritas.all? { |metodo, caminho, _| metodo == 'POST' && caminho == '/v1/betaBuildLocalizations' })
    assert_equal %w[en-US pt-BR], @api.build_locales.map { |r| r['attributes']['locale'] }.sort
    %w[pt-BR en-US].each do |locale|
      assert_equal "#{ROTULO_PROD}\n\n#{AppStoreConnect::Job::TEXTOS_BETA[locale]['whatsNew']}", whats_new(locale)
    end
    relacao = @api.escritas.first[2]['data']['relationships']['build']['data']
    assert_equal({'type'=>'builds', 'id'=>'build-ci'}, relacao)
    assert_includes @out.string, "O que testar gravado pela API: #{ROTULO_PROD}"
  end

  def test_atualiza_so_a_primeira_linha_e_preserva_o_que_a_pessoa_escreveu
    localizacao('pt-BR', "Frila-Beta · frila-dev\n\nTeste o convite da vaga.\nRelate no TestFlight.")
    localizacao('en-US', 'Texto de uma pessoa, sem rótulo')
    run_notas
    assert_equal ['PATCH', 'PATCH'], @api.escritas.map(&:first)
    assert_equal "#{ROTULO_PROD}\n\nTeste o convite da vaga.\nRelate no TestFlight.", whats_new('pt-BR')
    assert_equal "#{ROTULO_PROD}\n\nTexto de uma pessoa, sem rótulo", whats_new('en-US')
    assert_equal ['whatsNew'], @api.escritas.first[2]['data']['attributes'].keys
  end

  def test_rotulo_de_ensaio_e_aceito_e_troca_o_rotulo_anterior_inteiro
    @conteudo = "#{ROTULO_BETA} · ensaio de falha\n"
    localizacao('pt-BR', "#{ROTULO_BETA}\nlinha de pessoa")
    localizacao('en-US', "#{ROTULO_BETA}\r\nlinha de pessoa")
    run_notas
    assert_equal "#{ROTULO_BETA} · ensaio de falha\nlinha de pessoa", whats_new('pt-BR')
    assert_equal "#{ROTULO_BETA} · ensaio de falha\r\nlinha de pessoa", whats_new('en-US')
  end

  def test_idempotente_nao_duplica_nem_apaga_texto_de_pessoa
    localizacao('pt-BR', 'Texto de pessoa em pt-BR')
    run_notas
    antes = @api.escritas.size
    esperado = @api.build_locales.map { |r| r['attributes'].dup }
    2.times { run_notas }
    assert_equal antes, @api.escritas.size
    assert_equal esperado, @api.build_locales.map { |r| r['attributes'] }
    assert_equal 2, @api.build_locales.size
    assert_equal "#{ROTULO_PROD}\n\nTexto de pessoa em pt-BR", whats_new('pt-BR')
    assert_includes @out.string, 'nada a gravar'
  end

  def test_pessoa_edita_depois_do_rotulo_e_o_proximo_envio_so_troca_o_rotulo
    run_notas
    @api.build_locales.each { |r| r['attributes']['whatsNew'] += "\n\nAcrescentado por uma pessoa" }
    @conteudo = "#{ROTULO_BETA}\n"
    run_notas
    %w[pt-BR en-US].each do |locale|
      assert_equal "#{ROTULO_BETA}\n\n#{AppStoreConnect::Job::TEXTOS_BETA[locale]['whatsNew']}\n\nAcrescentado por uma pessoa", whats_new(locale)
    end
  end

  def test_espera_o_processamento_e_grava_quando_fica_valido
    self.estado_do_build = 'PROCESSING'
    run_notas(espera: 60, intervalo: 30) { self.estado_do_build = 'VALID' }
    assert_equal [30], @dormidas
    assert_includes @out.string, "Build #{NUMERO}: PROCESSING; nova consulta em 30s"
    assert_equal 2, @api.escritas.size
  end

  def test_build_ainda_nao_processado_nao_escreve
    self.estado_do_build = 'PROCESSING'
    erro = assert_raises(AppStoreConnect::Erro) { run_notas(espera: 2, intervalo: 1) }
    assert_includes erro.message, 'não ficou processado'
    assert_equal [1, 1], @dormidas
    assert_empty @api.escritas
    assert_empty @api.build_locales
  end

  def test_build_que_ainda_nao_aparece_na_api_espera_e_nao_escreve
    @api.builds = []
    erro = assert_raises(AppStoreConnect::Erro) { run_notas(espera: 1, intervalo: 1) }
    assert_includes erro.message, 'não ficou processado'
    assert_equal [1], @dormidas
    assert_includes @out.string, 'ainda não listado'
    assert_empty @api.escritas
  end

  def test_outro_numero_de_build_nunca_recebe_o_texto
    @api.builds.first['attributes']['version'] = '20261105.101010'
    assert_raises(AppStoreConnect::Erro) { run_notas }
    assert_empty @api.escritas
    @api.builds = [@api.builds.first, @api.builds.first.merge('id'=>'build-gemeo', 'attributes'=>@api.builds.first['attributes'].merge('version'=>NUMERO)),
      @api.builds.first.merge('id'=>'build-gemeo-2', 'attributes'=>@api.builds.first['attributes'].merge('version'=>NUMERO))]
    erro = assert_raises(AppStoreConnect::Erro) { run_notas }
    assert_includes erro.message, 'Mais de um build'
    assert_empty @api.escritas
  end

  def test_build_recusado_ou_expirado_para_sem_esperar_e_sem_escrever
    %w[FAILED INVALID].each do |estado|
      self.estado_do_build = estado
      erro = assert_raises(AppStoreConnect::Erro) { run_notas(espera: 60, intervalo: 30) }
      assert_includes erro.message, estado
    end
    self.estado_do_build = 'VALID'
    @api.builds.first['attributes']['expired'] = true
    assert_raises(AppStoreConnect::Erro) { run_notas }
    assert_empty @dormidas
    assert_empty @api.escritas
  end

  def test_versao_do_build_diferente_da_entrada_nao_escreve
    @api.release['attributes']['version'] = '0.5.0'
    assert_raises(AppStoreConnect::Erro) { run_notas }
    assert_empty @api.escritas
  end

  def test_api_recusando_a_escrita_vira_erro_sem_dado_sensivel
    transporte = lambda do |req|
      next @api.call(req) if req.method == 'GET'
      Struct.new(:code, :body).new('403', JSON.generate({'errors'=>[{'detail'=>'segredo-da-api voce@example.invalid'}]}))
    end
    erro = assert_raises(AppStoreConnect::ErroAPI) { run_notas(transporte: transporte) }
    assert_equal 403, erro.status
    assert_empty @api.escritas
    [@out.string, erro.message].each do |texto|
      refute_includes texto, 'segredo-da-api'
      refute_includes texto, 'jwt-falso'
      refute_match(/\S+@\S+/, texto)
    end
  end

  def test_api_fora_do_ar_durante_a_espera_falha_sem_escrever
    transporte = ->(_) { Struct.new(:code, :body).new('503', '') }
    erro = assert_raises(AppStoreConnect::ErroAPI) { run_notas(transporte: transporte) }
    assert_equal 503, erro.status
    assert_empty @api.escritas
  end

  def test_api_que_nao_confirma_o_rotulo_falha
    transporte = lambda do |req|
      resposta = @api.call(req)
      next resposta unless req.method == 'GET' && req.uri.path.end_with?('/betaBuildLocalizations') && !@api.escritas.empty?
      Struct.new(:code, :body).new('200', JSON.generate({'data'=>[{'id'=>'x', 'attributes'=>{'locale'=>'pt-BR', 'whatsNew'=>'outra coisa'}}]}))
    end
    erro = assert_raises(AppStoreConnect::Erro) { run_notas(transporte: transporte) }
    assert_includes erro.message, 'não confirmou'
  end

  def test_texto_ausente_ou_invalido_nao_chama_a_api
    entradas = [nil, '', '   ', "\n\n", ROTULO_PROD + "\nsegunda linha\n", 'Frila-Dev · frila-dev', 'Cole isto à mão', "\xff\xfe".dup.force_encoding('UTF-8'),
      "Frila-Prod · #{'x' * 201}"]
    entradas.each do |conteudo|
      @conteudo = conteudo
      assert_raises(AppStoreConnect::Erro, conteudo.inspect) { run_notas }
    end
    assert_raises(AppStoreConnect::Erro) { run_notas(arquivo: nil) }
    assert_raises(AppStoreConnect::Erro) { run_notas(leitor: ->(_) { raise Errno::ENOENT }) }
    # Só a busca do app (anterior à validação) pode ter acontecido: nenhuma consulta de build, nenhuma escrita.
    assert_empty @api.chamadas.reject { |_, caminho, _| caminho == '/v1/apps' }
    assert_empty @dormidas
  end

  def test_nao_passa_do_limite_de_4000_caracteres_da_apple
    localizacao('pt-BR', 'a' * 4000)
    erro = assert_raises(AppStoreConnect::Erro) { run_notas }
    assert_includes erro.message, '4000'
    assert_empty @api.escritas
  end

  def test_entradas_invalidas_nao_chegam_a_api
    assert_raises(AppStoreConnect::Erro) { run_notas(numero: nil) }
    assert_raises(AppStoreConnect::Erro) { run_notas(numero: '20261106;rm') }
    assert_raises(AppStoreConnect::Erro) { run_notas(versao: 'incorreta') }
    assert_raises(AppStoreConnect::Erro) { run_notas(intervalo: 0) }
    assert_raises(AppStoreConnect::Erro) { run_notas(espera: 99999) }
    assert_empty @api.escritas
    refute @api.build_query
  end

  def test_leitor_padrao_le_utf8_mesmo_com_locale_c
    require 'tmpdir'
    Dir.mktmpdir do |pasta|
      caminho = File.join(pasta, 'o-que-testar.txt')
      File.write(caminho, "#{ROTULO_PROD}\n")
      client = AppStoreConnect::Client.new(token: -> { 'jwt-falso' }, aplicar: true, transport: @api.method(:call))

      AppStoreConnect::Job.new(client: client, log: @log, acao: 'notas-do-build', aplicar: true, emails: '', grupo: 'IGNORADO',
        sem_referencias_alcool: false, verificacao_idade: true, numero_build: NUMERO, notas_arquivo: caminho, espera: 0, intervalo: 1).run
    end
    assert_equal ROTULO_PROD, whats_new('pt-BR').lines.first.strip
  end

  def test_inteiros_do_ambiente
    assert_equal 1200, AppStoreConnect.inteiro({}, 'ASC_ESPERA_SEGUNDOS', '1200')
    assert_equal 5, AppStoreConnect.inteiro({'ASC_INTERVALO_SEGUNDOS'=>'5'}, 'ASC_INTERVALO_SEGUNDOS', '30')
    ['-1', 'abc', '1.5', ''].each do |valor|
      assert_raises(AppStoreConnect::Erro) { AppStoreConnect.inteiro({'X'=>valor}, 'X', '1') }
    end
  end

  def test_workflow_do_testflight_grava_depois_do_envio_sem_derrubar_o_envio
    require 'yaml'
    workflow = YAML.safe_load(File.read(File.join(__dir__, '../../.github/workflows/testflight.yml')))
    passos = workflow['jobs']['testflight']['steps']
    nomes = passos.map { |p| p['name'] }
    envio = nomes.index('Archive, conferência, símbolos e envio')
    gravar = nomes.index('Gravar o esquema em "O que testar"')
    limpeza = nomes.index('Restaurar keychains e apagar identidade de distribuição')
    refute_nil gravar
    assert envio < gravar && gravar < limpeza, 'o passo novo vem depois do envio e antes da limpeza'
    passo = passos[gravar]
    assert_equal true, passo['continue-on-error']
    assert_includes passo['if'], "FRILA_ENVIAR == '1'"
    assert_equal '${{ secrets.APP_STORE_CONNECT_API_KEY_P8 }}', passo['env']['ASC_KEY_P8']
    assert_equal 'notas-do-build', passo['env']['ASC_ACAO']
    assert_equal 'true', passo['env']['ASC_APLICAR']
    comando = passo['run']
    assert_includes comando, 'ruby Scripts/app-store-connect.rb'
    assert_includes comando, 'o-que-testar.txt'
    assert_includes comando, 'GITHUB_STEP_SUMMARY'
    assert_includes comando, 'exit 0', 'falha na gravação não derruba o envio já feito'
    refute_match(/\$\{\{\s*inputs\./, comando)
  end
end

# Ação privacidade: lê o privacyPolicyUrl de cada appInfo e localização; com aplicar, troca só no
# appInfo editável. Respostas sintéticas em FixturesAppStoreConnect/privacidade.json; nada vai à Apple.
class APIPrivacidadeDeExemplo < APIDeExemplo
  attr_accessor :ignorar_patch

  def initialize
    super
    extra = JSON.parse(File.read(File.join(__dir__, 'FixturesAppStoreConnect/privacidade.json')))
    dados['appInfos'] = extra['appInfos']
    dados['appInfoLocalizations'] = extra['appInfoLocalizations']
  end

  def call(req)
    path, method = req.uri.path, req.method
    body = req.body ? JSON.parse(req.body) : nil
    result = if method == 'GET' && path =~ %r{\A/v1/appInfos/([^/]+)/appInfoLocalizations\z}
      dados['appInfoLocalizations'].fetch($1, [])
    elsif method == 'PATCH' && path =~ %r{\A/v1/appInfoLocalizations/([^/]+)\z}
      loc = dados['appInfoLocalizations'].values.flatten.find { |l| l['id'] == $1 }
      loc['attributes'].merge!(body['data']['attributes']) unless ignorar_patch
      loc
    else
      return super
    end
    chamadas << [method, path, body]
    Struct.new(:code, :body).new('200', JSON.generate({'data'=>result}))
  end

  def url(local_id)
    dados['appInfoLocalizations'].values.flatten.find { |l| l['id'] == local_id }['attributes']['privacyPolicyUrl']
  end
end

class PrivacidadeTest < Minitest::Test
  NOVA = 'https://frilabr.com/privacidade'.freeze

  def setup
    @api = APIPrivacidadeDeExemplo.new
    @out = StringIO.new
    @log = AppStoreConnect::Log.new(@out, github: false)
  end

  def rodar(aplicar: false)
    client = AppStoreConnect::Client.new(token: -> { 'jwt-falso' }, aplicar: aplicar, transport: @api.method(:call))
    AppStoreConnect::Job.new(client: client, log: @log, acao: 'privacidade', aplicar: aplicar, emails: '', grupo: 'IGNORADO',
      sem_referencias_alcool: false, verificacao_idade: true).run
  end

  def test_sem_aplicar_so_le_cada_app_info_com_estado_e_cada_localizacao
    rodar
    assert_empty @api.escritas
    assert @api.chamadas.all? { |metodo, _, _| metodo == 'GET' }
    assert_includes @out.string, 'AppInfo info-no-ar: estado=READY_FOR_DISTRIBUTION; localizações=1'
    assert_includes @out.string, 'AppInfo info-1: estado=PREPARE_FOR_SUBMISSION; localizações=3'
    assert_includes @out.string, 'AppInfo info-no-ar · pt-BR: privacyPolicyUrl=https://frila.netlify.app/privacidade'
    assert_includes @out.string, 'AppInfo info-1 · en-US: privacyPolicyUrl=(vazio)'
    assert_includes @out.string, "Plano: trocar privacyPolicyUrl para #{NOVA} em 3 localização(ões) do appInfo info-1"
  end

  def test_url_fora_do_padrao_nao_vai_para_o_log
    rodar
    assert_includes @out.string, 'AppInfo info-1 · es-MX: privacyPolicyUrl=(fora do padrão; não impresso)'
    refute_includes @out.string, 'javascript'
  end

  def test_com_aplicar_troca_so_no_app_info_editavel_e_rele
    rodar(aplicar: true)
    patches = @api.escritas
    assert_equal %w[/v1/appInfoLocalizations/loc-1-pt /v1/appInfoLocalizations/loc-1-en /v1/appInfoLocalizations/loc-1-es], patches.map { |_, path, _| path }
    assert patches.all? { |metodo, _, body| metodo == 'PATCH' && body['data']['attributes'] == {'privacyPolicyUrl'=>NOVA} }
    %w[loc-1-pt loc-1-en loc-1-es].each { |loc| assert_equal NOVA, @api.url(loc) }
    assert_equal 'https://frila.netlify.app/privacidade', @api.url('loc-no-ar-pt'), 'o appInfo no ar não é tocado'
    assert_includes @out.string, "privacyPolicyUrl confirmado pela API em 3 localização(ões): #{NOVA}"
    # Rodar de novo não escreve nada.
    antes = @api.escritas.size
    rodar(aplicar: true)
    assert_equal antes, @api.escritas.size
    assert_includes @out.string, 'Plano: nada a trocar'
  end

  def test_sem_app_info_editavel_nao_escreve
    @api.dados['appInfos'].each { |info| info['attributes']['appStoreState'] = 'READY_FOR_DISTRIBUTION' }
    rodar
    assert_includes @out.string, 'Plano: nenhuma troca; é preciso um único appInfo em PREPARE_FOR_SUBMISSION (há 0)'
    assert_raises(AppStoreConnect::Erro) { rodar(aplicar: true) }
    assert_empty @api.escritas
  end

  def test_dois_app_infos_editaveis_nao_escreve
    @api.dados['appInfos'].each { |info| info['attributes']['appStoreState'] = 'PREPARE_FOR_SUBMISSION' }
    rodar
    assert_includes @out.string, 'Plano: nenhuma troca; é preciso um único appInfo em PREPARE_FOR_SUBMISSION (há 2)'
    erro = assert_raises(AppStoreConnect::Erro) { rodar(aplicar: true) }
    assert_includes erro.message, 'É necessário um único appInfo em PREPARE_FOR_SUBMISSION'
    assert_empty @api.escritas
  end

  def test_api_que_nao_confirma_a_troca_falha
    @api.ignorar_patch = true
    erro = assert_raises(AppStoreConnect::Erro) { rodar(aplicar: true) }
    assert_includes erro.message, 'A API não confirmou o novo privacyPolicyUrl'
  end

  def test_workflow_oferece_a_acao_privacidade
    require 'yaml'
    workflow = YAML.safe_load(File.read(File.join(__dir__, '../../.github/workflows/app-store-connect.yml')))
    gatilho = workflow['on'] || workflow[true]
    assert_includes gatilho['workflow_dispatch']['inputs']['acao']['options'], 'privacidade'
  end
end
