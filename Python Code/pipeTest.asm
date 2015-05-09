# this program is to test pipelining
		addi $1, $0, 10
		addi $2, $1, 15
		addi $3, $0, 20
		addi $4, $0, 30
		addi $5, $0, 40
		addi $6, $0, 50
		add $7, $1, $2
EoP: 	beq $0, $0, EoP