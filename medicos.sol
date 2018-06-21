pragma solidity ^0.4.1;

// Autores: Jose Luis Conradi Hoffmann (15100745)
//          Leonardo Passig Horstmann (15103030)

import "github.com/Arachnid/solidity-stringutils/strings.sol";
//sistema de controle dos medicos
contract SistemaMedico {
    
    using strings for *;
    
    //estrutura que define um medico
    struct Medico {
        string nome;
        bool ativo;
        bool isValue;
        uint32 uf; //use codigo (inteiro) para ufs
    }
    
    address admin = msg.sender;
    mapping(address => Medico) medicos;

    //apenas admin (quem criou o contract) pode adicionar medicos
    function criar(address med, string nome, bool ativo, uint32 _uf) apenasAdmin(msg.sender) public  {
        if (compareStrings(nome, "")) revert();
        medicos[med].nome = nome;
        medicos[med].ativo = ativo;
        medicos[med].isValue = true;
        medicos[med].uf = _uf;
    }
    
    modifier apenasAdmin (address conta) {
        require(conta == admin);
        _;
    }
    //verifica se o endereco e de um medico
    function medicoValido(address med) public view returns (bool) {
        return (medicos[med].isValue);
    }
    //retorna o codigo da uf do medico
    function ufMedico (address med) public view returns (uint32) {
        return medicos[med].uf;
    }
    //retorna string com info concatenada
    function informacoesMedico(address med) public view returns (string informacoes) {
        if (medicoValido(med)) {
            informacoes = "\nNome: ";
            informacoes = concatenar(informacoes, medicos[med].nome);
            if (medicos[med].ativo) {
                informacoes = concatenar(informacoes, "\nAtivo!");
            } else {
                informacoes = concatenar(informacoes, "\nInativo!");
            }
        } else {
            informacoes = "Não existente!";
        }
    }
    //desabilita um medico
    function desativarMedico(address med) public {
        if (!medicoValido(med)) revert();
        if (med == msg.sender || msg.sender == admin)
        medicos[med].ativo = false;
    }
    //concatena strings
    function concatenar(string a, string b) private view returns (string result) {
        result = a.toSlice().concat(b.toSlice());
    }
    //compara strings 
    function compareStrings (string a, string b) private view returns (bool){
       return keccak256(a) == keccak256(b);
   }

}

//contract para cadastro de pacientes
contract Sistema_Paciente {
    
    using strings for *;
    //definicao de um paciente
    struct Paciente {
        string _nome;
        bool _existe;//variavel de checagem
        uint32 _uf;//use inteiro como codigo
        string _prontuario;
    }
    
    SistemaMedico sis_m; //endereco para sistema dos medicos (para as verificacoes necessarias)
    Sistema_Acesso_Prontuario sis_acesso; //endereco do sistema de acesso (para informar alteracoes no log)
    
    mapping (address => Paciente) pacientes;
    //funcao para pegar parametro do sis_med, cadastrar antes de usar outras funcoes
    function endereca_sistema_medico (address sis_med) public {
        sis_m = SistemaMedico(sis_med);
    }
    //funcao para pegar parametro do sis_acesso, cadastrar antes de usar outras funcoes
    function endereca_sistema_acesso (address _sis_acesso) public {
        sis_acesso = Sistema_Acesso_Prontuario(_sis_acesso);
    }
    //pega a uf de um paciente em especifico
    function uf_paciente (address _p) public view returns (uint32) {
        if (verifica_se_paciente(_p)) {
            return pacientes[_p]._uf;
        } else {
            revert();
        }
    }
    //adiciona um paciente (um medico deve fazer na primeira consulta)
    function adiciona_paciente(address _p, string _n, uint32 _uf_p) public {
        if (!sis_m.medicoValido(msg.sender)) revert();
        pacientes[_p]._nome = _n;
        pacientes[_p]._existe = true;
        pacientes[_p]._uf = _uf_p;
        primeira_escrita(_p, "Prontuario: ", msg.sender);
    }
    //altera cod local do paciente (apenas o paciente tem permissao)
    function atualiza_local (uint32 _uf_n) public {
        if (verifica_se_paciente(msg.sender)) {
            pacientes[msg.sender]._uf = _uf_n;
        } else {
            revert();
        }
    }
    //retorna se o paciente em questao esta cadastrado
    function verifica_se_paciente(address _p) public returns (bool) {
        return (pacientes[_p]._existe);
    }
    //retorna prontuario do paciente, registrando o acesso feito
    function le_prontuario (address _p) public returns (string) {
        address m = msg.sender;
        string memory _aux =  "leitura";
        if (verifica_se_paciente(_p)  && sis_m.medicoValido(m)) {
            sis_acesso.acessa(_p, pacientes[_p]._uf, sis_m.ufMedico(m), m, _aux);
            return (pacientes[_p]._prontuario);
        } else {
            return "nao e paciente ou médico invalido!";
        }
    }
    //inicia o prontuario do paciente, nao registra como acesso, pois e so procedimento de criacao
    function primeira_escrita(address _p, string _n, address m) internal {
        if (verifica_se_paciente(_p) && sis_m.medicoValido(m)) {
            string aux = pacientes[_p]._prontuario;
            pacientes[_p]._prontuario = concatenar(aux, _n);
            //sis_acesso.acessa(_p, pacientes[_p]._uf, sis_m.ufMedico(m), m, _n);
        } else {
            revert();
        }
    }
    //escreve dados no prontuario, registra acesso e escrita
    function escreve_no_prontuario (address _p, string _n) public {
        address m = msg.sender;
        if (verifica_se_paciente(_p) && sis_m.medicoValido(m)) {
            string aux = pacientes[_p]._prontuario;
            pacientes[_p]._prontuario = concatenar(aux, _n);
            sis_acesso.acessa(_p, pacientes[_p]._uf, sis_m.ufMedico(m), m, _n);
        } else {
            revert();
        }
    }
    //concatena strings
    function concatenar(string a, string b) public view returns (string result) {
        result = a.toSlice().concat(b.toSlice());
    }
}
//contract que controla o acesso aos prontuarios
contract Sistema_Acesso_Prontuario {
    
    using strings for *;
    //struct que define um acesso
    struct Acesso {
        uint256 data; //timestamp
        address medico;
        uint32 uf; //inteiro como cod
        bool edicao; //define se foi so visualizacao ou houve alteracao
        string texto; //texto da alteracao ou palavra "leitura"
        bool anomalia; //marca estranhesa para o caso do acesso ser feito em uf diferente do paciente
    }
    Sistema_Paciente sis_p; //endereco para sistema de pacientes (usado para checagens)
    SistemaMedico sis_m;//endereco para sistema de medicos (usado para checagens)
    //o prontuario e endereçado pelo endereço do paciente
    mapping(address => Acesso[]) acessos;
    //numero de escritas no prontuario do paciente
    mapping(address => uint32) size;
    //funcao para enderecamento dos sistemas externos, usar antes
    function endereca_sistema_paciente (address sis_pac) public {
        sis_p = Sistema_Paciente(sis_pac);
    }
    //funcao para enderecamento dos sistemas externos, usar antes
    function endereca_sistema_medico (address sis_med) public {
        sis_m = SistemaMedico(sis_med);
    }
    //grava um acesso feito ao prontuario e o caracteriza como anomalia ou nao
    function acessa (address _p, uint32 ufP, uint32 ufM, address m, string _info) external {
        size[_p] += 1;
        bool anomalia = true;
        if (ufP == ufM) {
            anomalia = false;
        }
        acessos[_p].push( Acesso (now, m, ufM, false, _info, anomalia));
    }
    //lista o acesso selecionado no index pelo cliente, ia-se usar um for para retornar todos, mas o sistema trava com o for
    function lista_acessos (uint32 index) public view returns (string) {
        if (sis_p.verifica_se_paciente(msg.sender)) {
            uint32 i = 0;
            string memory ret = "";
            string memory aux;
            //for (i = 0; i < size[msg.sender]; i++) {
                aux = "{ ";
                aux = concatenar(aux, ", Medico: ");
                aux = concatenar(aux, sis_m.informacoesMedico(acessos[msg.sender][index].medico));
                if (acessos[msg.sender][index].anomalia)
                    aux = concatenar(aux, ", Anomalia!");
                aux = concatenar(aux, " };");
                ret = concatenar(ret, aux);
            //}
            return ret;
        }
        return "Paciente nao Existe";
    }

    //concatena duas strings
    function concatenar(string a, string b) private view returns (string result) {
        result = a.toSlice().concat(b.toSlice());
    }
    //compara duas strings
    function compareStrings (string a, string b) private returns (bool){
       return keccak256(a) == keccak256(b);
    }
    
}
