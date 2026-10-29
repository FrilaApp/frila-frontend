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
