// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TicketSale is ERC721Enumerable {
    //Este contrato esta hecho solo para interacuar en la red y que sea
    //mas dificil falsificar un boleto, pero aun se puede mejorar si
    //ya se quiere pagar con criptomonedas y si se quieren interactuar
    //los usuarios con sus propias carteras como metamask
    using Counters for Counters.Counter;

    Counters.Counter private EventsCounter;
    Counters.Counter private ZonesCounter;

    // Almacena la direccion del propietario del contrato
    address private ownerContract;

    event TicketIssued(address indexed buyer, uint amount);
    event EventCreated(uint indexed eventId, string name, address owner);
    event ZoneCreated(uint indexed zoneId, uint eventId, string name, uint price, uint totalTickets);
    event TicketRedeem(uint256 eventId, uint256 zoneId, uint256 indexed tokenId);

    // Almacena las direcciones de los usuarios permitidos para crear eventos, zonas y demas
    mapping(address => bool) private allowedUsers; 

    // Informacion del boleto
    struct TicketData {
        uint256 zoneId;
        bool redeemed;
    }

    TicketData[] public tickets;

    // Estructura para almacenar la información de un evento
    struct Event {
        string name;                
        address owner; // direccion del dueño del evento
        bool finished;
        uint256 raised;
    }

    Event[] public events;

    // Estructura para almacenar la información de una zona
    struct Zone {
        uint eventId;
        string name;
        uint price;
        uint totalTickets;
        uint remainingTickets;
    }

    Zone[] public zones;

    mapping(uint256 => string) private _tokenInfo;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("EventTickets", "TIX") {
        ownerContract = msg.sender;
        allowedUsers[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == ownerContract, "Solo el propietario puede llamar a esta funcion");
        _;
    }

    modifier onlyAllowed() {
        require(allowedUsers[msg.sender], "No tienes permiso para acceder");
        _;
    }

    // Función para agregar la dirección de un usuario a la lista de usuarios permitidos
    function grantAccess(address _user) public onlyOwner {
        allowedUsers[_user] = true;
    }
    
    // Función para remover la dirección de un usuario de la lista de usuarios permitidos
    function revokeAccess(address _user) public onlyOwner {
        allowedUsers[_user] = false;
    }

    //Funcion para crear eventos
    function createEvent(string memory _name, address _owner) public onlyAllowed {
        events.push(Event(_name, _owner, false, 0));
        uint id = events.length - 1;
        emit EventCreated(id, _name, _owner);
    }

    //Funcion pra crear zonas
    function createZone(uint _eventId, string memory _name, uint _price, uint _totalTickets) public onlyAllowed {
        require(events[_eventId].owner == address(0), "Invalid event ID");
        require(_eventId <= EventsCounter.current(), "Invalid event ID");
        require(events[_eventId].finished == false, "Evento terminado");

        zones.push(Zone(_eventId, _name, _price, _totalTickets, _totalTickets));
        uint id = zones.length - 1;
        emit ZoneCreated(id, _eventId, _name, _price, _totalTickets);
    }

    //Funcion para aumentar el numero de tickets a una zona si es necesario - falta


    //Funcion para emitir el token
    function _issuedTickets(uint _zoneId, uint _numTickets, address _buyer) public onlyAllowed {
        require(events[zones[_zoneId].eventId].finished == false, "Evento terminado");
        require(zones[_zoneId].remainingTickets >= _numTickets, "Not enough tickets available");

        events[zones[_zoneId].eventId].raised = zones[_zoneId].price * _numTickets;
        for (uint i = 0; i < _numTickets; i++) {
            tickets.push(TicketData(_zoneId, false));
            //Se puede hacer un id de token mas personalizado
            uint256 newTicketId = tickets.length - 1;
            _safeMint(_buyer, newTicketId);

            zones[_zoneId].remainingTickets--;
        }

        emit TicketIssued(_buyer,  _numTickets);
    }

    function zoneExists(uint zoneId) public view returns (bool) {
        // Comprobar si la zona existe
        if (zones[zoneId].eventId == 0) {
            return false;
        }
        
        // Comprobar si el evento asociado a la zona existe
        if (events[zones[zoneId].eventId].owner == address(0)) {
            return false;
        }
        
        // Si llegamos hasta aquí, la zona y el evento existen
        return true;
    }

    //Funciona para redimir el token
    //Verificar si ya fue redimido
    function redeem(uint256 _tokenId, address _owner) public onlyAllowed {
        require(_exists(_tokenId), "Token no existe");
        require(ownerOf(_tokenId) == _owner, "El ticket pertenece a otra persona");
        require(!tickets[_tokenId].redeemed, "El token ya fue redimido");
        bool exist = zoneExists(tickets[_tokenId].zoneId);
        require(exist, "Invalid event and zone ID");
        tickets[_tokenId].redeemed = true;
    }


    //Devuelve las zonas de un evento - esto se deberia hacer en la Dapp
    //Revisar https://github.com/Calpoog/blockchain-ticketing/blob/master/src/App.js
    //Las lineas 82 a 120 
    function getZonesOfEvent(uint eventId) public view returns (uint[] memory) {
        uint numZones = 0;

        uint256 zonesIndex = zones.length;
        
        // Calcular el número de zonas del evento
        for (uint i = 1; i <= zonesIndex; i++) {
            if (zones[i].eventId == eventId) {
                numZones++;
            }
        }
        
        // Crear un array de zonas del tamaño correcto
        uint[] memory result = new uint[](numZones);
        
        // Rellenar el array con los IDs de las zonas del evento
        uint index = 0;
        for (uint i = 1; i <= zonesIndex; i++) {
            if (zones[i].eventId == eventId) {
                result[index] = i;
                index++;
            }
        }
        
        return result;
    }

    //Devuelve los eventos que no han finalizado - esto se deberia hacer en la Dapp
    //Revisar https://github.com/Calpoog/blockchain-ticketing/blob/master/src/App.js
    //Las lineas 82 a 120 
    function getUnfinishedEvents() public view returns (Event[] memory) {
        uint numUnfinishedEvents = 0;
        
        // Calcular el número de eventos no finalizados
        for (uint i = 1; i <= EventsCounter.current(); i++) {
            if (!events[i].finished) {
                numUnfinishedEvents++;
            }
        }
        
        // Crear un array de eventos no finalizados del tamaño correcto
        Event[] memory result = new Event[](numUnfinishedEvents);
        
        // Rellenar el array con los eventos no finalizados
        uint index = 0;
        for (uint i = 1; i <= EventsCounter.current(); i++) {
            if (!events[i].finished) {
                result[index] = events[i];
                index++;
            }
        }
        
        return result;
    }


    //Devuelve los Id de los Tokens(Boketos-tickets) de propiedad de una direccion o persona
    //asociada a cuenta
    function ticketsOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    //Funcion para terminar evento - ojala solo el dueño del contrato lo pueda hacer
    function finishEvent(uint256 _eventId) public onlyAllowed {
        require(events[_eventId].owner == address(0), "Invalid event ID");
        events[_eventId].finished = true;
    }

    //Funcion para trasnferFrom sea solo un porcentaje y evitar la reventa o que se puedan autorizar
    //cierta cantidad de tokens a transferir

    //Tambien se pueden mejorar los id del token y como recuperar por dueño(cartera) los token que tiene
    //Para ellos usar en la Dapp el sigiente codigo
    // MyToken myToken = MyToken(ContractAddress);
    // uint256 balance = myToken.balanceOf(0x1234567890123456789012345678901234567890);
    // uint256 tokenId = myToken.tokenOfOwnerByIndex(0x1234567890123456789012345678901234567890, 0); //Aqui el cero indica la posicion segun la cantidad de tokens
}


//Revisar Dapp https://github.com/Calpoog/blockchain-ticketing/blob/master/src/App.js
